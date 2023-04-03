// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract MoonPool is ERC721TokenReceiver, Owned, ReentrancyGuard {
    using FixedPointMathLib for uint96;
    using SafeTransferLib for address payable;

    struct Fee {
        // Collection owner-specified address
        address recipient;
        // Denominated in basis points (1 = 0.01%)
        uint96 bps;
    }

    struct Listing {
        // NFT seller, receives ETH upon sale
        address seller;
        // Denominated in ETH
        uint96 price;
    }

    // 10,000 basis points = 100%
    uint96 public constant BPS_BASE = 10_000;

    // Collection royalties can never exceed 10%
    uint80 public constant MAX_COLLECTION_ROYALTIES = 1_000;

    // Protocol fees can never exceed 0.5%
    uint80 public constant MAX_PROTOCOL_FEES = 50;

    // NFT collection contract
    ERC721 public immutable collection;

    // NFT collection listings
    mapping(uint256 id => Listing listing) public collectionListings;

    // Set by the Moonbase team upon outreach from the collection owner
    Fee public collectionRoyalties;

    // Protocol fees are charged upon each exchange and results in...
    // MOON rewards being minted for both the seller and the buyer
    Fee public protocolFees;

    event SetCollectionRoyalties(address indexed recipient, uint96 bps);
    event SetProtocolFees(address indexed recipient, uint96 bps);
    event List(address indexed seller, uint256 indexed id, uint96 price);
    event ListMany(address indexed seller, uint256[] ids, uint96[] prices);
    event CancelListing(address indexed seller, uint256 indexed id);
    event EditListing(address indexed seller, uint256 indexed id, uint96 price);
    event Buy(
        address indexed buyer,
        address indexed seller,
        uint256 indexed id,
        uint96 price,
        uint256 totalFees
    );
    event BuyMany(
        address indexed buyer,
        uint256[] ids,
        uint256 totalPrice,
        uint256 totalCollectionRoyalties,
        uint256 totalProtocolFees
    );

    error InvalidAddress();
    error InvalidNumber();
    error EmptyArray();
    error MismatchedArrays();
    error InsufficientFunds();
    error NotSeller();

    /**
     * @param _owner       address  Contract owner (can set royalties and fees only)
     * @param _collection  ERC721   NFT collection contract
     */
    constructor(address _owner, ERC721 _collection) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
        if (address(_collection) == address(0)) revert InvalidAddress();

        collection = _collection;
    }

    /**
     * @notice Set collection royalties
     * @param  recipient  address  Royalties recipient
     * @param  bps        uint96   Royalties in basis points (1 = 0.01%)
     */
    function setCollectionRoyalties(
        address recipient,
        uint96 bps
    ) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        if (bps > BPS_BASE) revert InvalidNumber();
        if (bps > MAX_COLLECTION_ROYALTIES) revert InvalidNumber();

        collectionRoyalties = Fee(recipient, bps);

        emit SetCollectionRoyalties(recipient, bps);
    }

    /**
     * @notice Set protocol fees
     * @param  recipient  address  Protocol fees recipient
     * @param  bps        uint96   Protocol fees in basis points (1 = 0.01%)
     */
    function setProtocolFees(address recipient, uint96 bps) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        if (bps > BPS_BASE) revert InvalidNumber();
        if (bps > MAX_PROTOCOL_FEES) revert InvalidNumber();

        protocolFees = Fee(recipient, bps);

        emit SetProtocolFees(recipient, bps);
    }

    /*///////////////////////////////////////////////////////////////
                            Seller Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice List a single NFT for sale
     * @param  id     uint256  NFT ID
     * @param  price  uint96   NFT price in ETH
     */
    function list(uint256 id, uint96 price) external nonReentrant {
        if (price == 0) revert InvalidNumber();

        collection.safeTransferFrom(msg.sender, address(this), id);

        collectionListings[id] = Listing(msg.sender, price);

        emit List(msg.sender, id, price);
    }

    /**
     * @notice List many NFTs for sale
     * @param  ids     uint256[]  NFT IDs
     * @param  prices  uint96[]   NFT prices
     */
    function listMany(
        uint256[] calldata ids,
        uint96[] calldata prices
    ) external nonReentrant {
        uint256 iLen = ids.length;

        if (iLen == 0) revert EmptyArray();
        if (iLen != prices.length) revert MismatchedArrays();

        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];

            collection.safeTransferFrom(msg.sender, address(this), id);

            collectionListings[id] = Listing(msg.sender, prices[i]);

            // Will not overflow since it's bound by the `ids` array's length
            unchecked {
                ++i;
            }
        }

        emit ListMany(msg.sender, ids, prices);
    }

    /**
     * @notice Cancel NFT listing and reclaim NFT
     * @param  id  uint256  NFT ID
     */
    function cancelListing(uint256 id) external nonReentrant {
        // Only the seller can cancel the listing
        if (collectionListings[id].seller != msg.sender) revert NotSeller();

        delete collectionListings[id];

        collection.safeTransferFrom(address(this), msg.sender, id);

        emit CancelListing(msg.sender, id);
    }

    /**
     * @notice Edit NFT listing price
     * @param  id     uint256  NFT ID
     * @param  price  uint96   NFT price
     */
    function editListing(uint256 id, uint96 price) external nonReentrant {
        if (price == 0) revert InvalidNumber();

        Listing storage listing = collectionListings[id];

        // Only the seller can edit the listing
        if (listing.seller != msg.sender) revert NotSeller();

        listing.price = price;

        emit EditListing(msg.sender, id, price);
    }

    /*///////////////////////////////////////////////////////////////
                            Buyer Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Buy a single NFT
     * @param   id         uint256  NFT ID
     * @return  totalFees  uint256  Total fees paid
     */
    function buy(
        uint256 id
    ) external payable nonReentrant returns (uint256 totalFees) {
        if (msg.value == 0) revert InsufficientFunds();

        Listing memory listing = collectionListings[id];

        // Delete listing before transferring NFT and ETH as a best practice
        delete collectionListings[id];

        if (msg.value < listing.price) revert InsufficientFunds();

        // Send NFT to buyer after verifying that they have enough ETH to cover the sale
        collection.safeTransferFrom(address(this), msg.sender, id);

        // Pay collection royalties
        if (collectionRoyalties.bps != 0) {
            uint256 _collectionRoyalties = listing.price.mulDivDown(
                collectionRoyalties.bps,
                BPS_BASE
            );

            totalFees += _collectionRoyalties;

            payable(collectionRoyalties.recipient).safeTransferETH(
                _collectionRoyalties
            );
        }

        // Pay protocol fees
        if (protocolFees.bps != 0) {
            uint256 _protocolFees = listing.price.mulDivDown(
                protocolFees.bps,
                BPS_BASE
            );

            totalFees += _protocolFees;

            payable(protocolFees.recipient).safeTransferETH(_protocolFees);
        }

        // Pay the listing price minus the total fees to the seller
        payable(listing.seller).safeTransferETH(listing.price - totalFees);

        emit Buy(msg.sender, listing.seller, id, listing.price, totalFees);
    }

    /**
     * @notice Buy a single NFT
     * @param   ids                       uint256[]  NFT IDs
     * @return  totalPrice                uint256    Total NFT price
     * @return  totalCollectionRoyalties  uint256    Total collection royalties
     * @return  totalProtocolFees         uint256    Total protocol fees
     */
    function buyMany(
        uint256[] calldata ids
    )
        external
        payable
        nonReentrant
        returns (
            uint256 totalPrice,
            uint256 totalCollectionRoyalties,
            uint256 totalProtocolFees
        )
    {
        uint256 iLen = ids.length;

        if (iLen == 0) revert EmptyArray();
        if (msg.value == 0) revert InsufficientFunds();

        // Cache these values to reduce redundant ops
        bool hasCollectionRoyalties = collectionRoyalties.bps != 0;
        bool hasProtocolFees = protocolFees.bps != 0;

        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];

            Listing memory listing = collectionListings[id];

            totalPrice += listing.price;

            // Check whether the buyer has enough ETH to cover all of the NFTs purchased
            if (msg.value < totalPrice) revert InsufficientFunds();

            delete collectionListings[id];

            // Send NFT to buyer after verifying that they have enough ETH
            collection.safeTransferFrom(address(this), msg.sender, id);

            // Enables us to calculate the post-fee ETH amount to transfer to the seller
            uint256 totalFees;

            // Pay collection royalties
            if (hasCollectionRoyalties) {
                uint256 _collectionRoyalties = listing.price.mulDivDown(
                    collectionRoyalties.bps,
                    BPS_BASE
                );

                totalFees += _collectionRoyalties;

                totalCollectionRoyalties += _collectionRoyalties;
            }

            // Pay protocol fees
            if (hasProtocolFees) {
                uint256 _protocolFees = listing.price.mulDivDown(
                    protocolFees.bps,
                    BPS_BASE
                );

                totalFees += _protocolFees;

                totalProtocolFees += _protocolFees;
            }

            // Pay the listing price minus the total fees to the seller
            payable(listing.seller).safeTransferETH(listing.price - totalFees);

            // Will not overflow since it's bound by the `ids` array's length
            unchecked {
                ++i;
            }
        }

        // Pay collection royalties and protocol fees in a single batched transfer
        payable(collectionRoyalties.recipient).safeTransferETH(
            totalCollectionRoyalties
        );
        payable(protocolFees.recipient).safeTransferETH(totalProtocolFees);

        emit BuyMany(
            msg.sender,
            ids,
            totalPrice,
            totalCollectionRoyalties,
            totalProtocolFees
        );
    }
}
