// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {Moon} from "src/Moon.sol";

contract MoonBook is ERC721TokenReceiver, ERC1155, Moon {
    using SafeTransferLib for address payable;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint96;

    struct Listing {
        // NFT seller, receives ETH upon sale
        address seller;
        // Denominated in ETH
        uint96 price;
    }

    struct ListingProceeds {
        // ETH proceeds from the NFT sale
        uint128 value;
        // ETH withheld from the NFT sale
        uint128 withheld;
    }

    uint8 private constant AMOUNT = 1;
    bytes private constant DATA = "";

    // 1% of proceeds are withheld and can be redeemed later
    uint128 public constant WITHHELD_PERCENT = 1;

    // Used for calculating fees
    uint128 public constant WITHHELD_PERCENT_BASE = 100;

    // NFT listings
    mapping(ERC721 collection => mapping(uint256 id => Listing listing))
        public listings;

    // NFT listing nonces
    mapping(bytes32 => uint256) public listingNonces;

    // NFT listing proceeds
    mapping(uint256 => ListingProceeds) public listingProceeds;

    error OnlySeller();
    error InvalidListing();

    constructor(address _staker, address _vault) Moon(_staker, _vault) {}

    function _getListingNonce(
        ERC721 collection,
        uint256 id
    ) private view returns (uint256) {
        return listingNonces[keccak256(abi.encodePacked(collection, id))];
    }

    function _computeListingId(
        ERC721 collection,
        uint256 id,
        uint96 price,
        uint256 nonce
    ) private pure returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(collection, id, price, nonce)));
    }

    // Considering updating logic to provide insight into asset
    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    /**
     * @notice List a NFT for sale
     * @param  collection  ERC721   NFT collection
     * @param  id          uint256  NFT ID
     * @param  price       uint96   NFT price in ETH
     */
    function list(
        ERC721 collection,
        uint256 id,
        uint96 price
    ) external nonReentrant {
        // Reverts if the NFT is not owned by msg.sender
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Set listing details
        listings[collection][id] = Listing(msg.sender, price);
    }

    /**
     * @notice List a NFT for sale
     * @param  collection  ERC721   NFT collection
     * @param  id          uint256  NFT ID
     * @param  price       uint96   NFT price in ETH
     * @return listingId   uint256  Listing ID
     */
    function listBeta(
        ERC721 collection,
        uint256 id,
        uint96 price
    ) external nonReentrant returns (uint256 listingId) {
        // Reverts if the NFT is not owned by msg.sender
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Mint a transferrable listing token for the user
        listingId = _computeListingId(
            collection,
            id,
            price,
            _getListingNonce(collection, id)
        );

        // Increment the listing nonce to prevent it from being reused
        ++listingNonces[keccak256(abi.encodePacked(collection, id))];

        // Set the user token balance to 1 for the listing ID
        balanceOf[msg.sender][listingId] = AMOUNT;

        require(
            msg.sender.code.length == 0 ||
                ERC1155TokenReceiver(msg.sender).onERC1155Received(
                    msg.sender,
                    address(0),
                    listingId,
                    AMOUNT,
                    DATA
                ) ==
                ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /**
     * @notice List many NFTs for sale
     * @param  collections  ERC721[]   NFT collections
     * @param  ids          uint256[]  NFT IDs
     * @param  prices       uint96[]   NFT prices in ETH
     */
    function listMany(
        ERC721[] calldata collections,
        uint256[] calldata ids,
        uint96[] calldata prices
    ) external nonReentrant {
        uint256 cLen = collections.length;

        // Loop body does not execute if cLen is zero, and tx reverts if the
        // array lengths are mismatched
        for (uint256 i; i < cLen; ) {
            ERC721 collection = collections[i];
            uint256 id = ids[i];

            // Reverts if the NFT is not owned by msg.sender
            collection.safeTransferFrom(msg.sender, address(this), id);

            // Set listing details
            listings[collection][id] = Listing(msg.sender, prices[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice List many NFTs for sale
     * @param  collections  ERC721[]   NFT collections
     * @param  ids          uint256[]  NFT IDs
     * @param  prices       uint96[]   NFT prices in ETH
     * @return listingIds   uint256[]  Listing IDs
     */
    function listManyBeta(
        ERC721[] calldata collections,
        uint256[] calldata ids,
        uint96[] calldata prices
    ) external nonReentrant returns (uint256[] memory listingIds) {
        uint256 cLen = collections.length;
        listingIds = new uint256[](cLen);

        // Loop body does not execute if cLen is zero, and tx reverts if the
        // array lengths are mismatched
        for (uint256 i; i < cLen; ) {
            ERC721 collection = collections[i];
            uint256 id = ids[i];

            // Reverts if the NFT is not owned by msg.sender
            collection.safeTransferFrom(msg.sender, address(this), id);

            // Set listing IDs
            listingIds[i] = _computeListingId(
                collection,
                id,
                prices[i],
                _getListingNonce(collection, id)
            );

            // Increment the listing nonce to prevent it from being reused
            ++listingNonces[keccak256(abi.encodePacked(collection, id))];

            // Mint a transferrable listing token for the user (one for each NFT)
            balanceOf[msg.sender][listingIds[i]] = AMOUNT;

            unchecked {
                ++i;
            }
        }

        require(
            msg.sender.code.length == 0 ||
                ERC1155TokenReceiver(msg.sender).onERC1155BatchReceived(
                    msg.sender,
                    address(0),
                    listingIds,
                    listingIds,
                    DATA
                ) ==
                ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /**
     * @notice Edit NFT listing price
     * @param  collection  ERC721   NFT collection
     * @param  id          uint256  NFT ID
     * @param  newPrice    uint96   New NFT price
     */
    function editListing(
        ERC721 collection,
        uint256 id,
        uint96 newPrice
    ) external {
        Listing storage listing = listings[collection][id];

        // msg.sender must be the listing seller, otherwise they cannot edit
        if (listing.seller != msg.sender) revert OnlySeller();

        listing.price = newPrice;
    }

    /**
     * @notice Edit NFT listing price
     * @param  collection  ERC721   NFT collection
     * @param  id          uint256  NFT ID
     * @param  price       uint96   Current NFT price
     * @param  nonce       uint256  Current NFT listing nonce
     * @param  newPrice    uint96   New NFT price
     */
    function editListingBeta(
        ERC721 collection,
        uint256 id,
        uint96 price,
        uint256 nonce,
        uint96 newPrice
    ) external {
        uint256 listingId = uint256(
            keccak256(abi.encodePacked(collection, id, price, nonce))
        );

        // Revert if msg.sender is not the listing owner
        if (balanceOf[msg.sender][listingId] == 0) revert OnlySeller();

        // Zero out the user's balance for the token id with the old price
        balanceOf[msg.sender][listingId] = 0;

        // Set the user's balance for the token id with the new price
        balanceOf[msg.sender][
            _computeListingId(collection, id, newPrice, nonce)
        ] = AMOUNT;
    }

    /**
     * @notice Cancel NFT listing and reclaim NFT
     * @param  collection  ERC721   NFT collection
     * @param  id          uint256  NFT ID
     */
    function cancelListing(
        ERC721 collection,
        uint256 id
    ) external nonReentrant {
        // msg.sender must be the listing seller, otherwise they cannot cancel
        if (listings[collection][id].seller != msg.sender) revert OnlySeller();

        delete listings[collection][id];

        // Return the NFT to the seller
        collection.safeTransferFrom(address(this), msg.sender, id);
    }

    /**
     * @notice Cancel NFT listing and reclaim NFT
     * @param  collection  ERC721   NFT collection
     * @param  id          uint256  NFT ID
     * @param  price       uint96   NFT price
     * @param  nonce       uint256  NFT listing nonce
     */
    function cancelListingBeta(
        ERC721 collection,
        uint256 id,
        uint96 price,
        uint256 nonce
    ) external nonReentrant {
        uint256 listingId = uint256(
            keccak256(abi.encodePacked(collection, id, price, nonce))
        );

        // Revert if msg.sender is not the listing owner
        if (balanceOf[msg.sender][listingId] == 0) revert OnlySeller();

        balanceOf[msg.sender][listingId] = 0;

        // Return the NFT to the seller
        collection.safeTransferFrom(address(this), msg.sender, id);
    }

    /**
     * @notice Buy a NFT
     * @param  collection  ERC721   NFT collection
     * @param  id          uint256  NFT ID
     */
    function buy(ERC721 collection, uint256 id) external payable nonReentrant {
        Listing memory listing = listings[collection][id];

        // Reverts if msg.value does not equal listing price
        if (msg.value != listing.price) revert InvalidAmount();

        // Delete listing before exchanging tokens
        delete listings[collection][id];

        // Send NFT to the buyer after confirming sufficient ETH was sent
        // Reverts if invalid listing (i.e. contract no longer has the NFT)
        collection.safeTransferFrom(address(this), msg.sender, id);

        // Calculate protocol fees
        uint256 fees = listing.price.mulDivDown(
            WITHHELD_PERCENT,
            WITHHELD_PERCENT_BASE
        );

        // Transfer the post-fee sale proceeds to the seller
        payable(listing.seller).safeTransferETH(listing.price - fees);

        // If there are fees, deposit them into the protocol contract, and distribute
        // MOON rewards to the seller (equal to the ETH fees they've paid)
        if (fees != 0) _mint(listing.seller, fees);
    }

    /**
     * @notice Buy a NFT
     * @param  collection  ERC721   NFT collection
     * @param  id          uint256  NFT ID
     * @param  price       uint96   NFT price
     * @param  nonce       uint256  NFT listing nonce
     * @param  seller      address  NFT seller
     */
    function buyBeta(
        ERC721 collection,
        uint256 id,
        uint96 price,
        uint256 nonce,
        address seller
    ) external payable nonReentrant {
        uint256 listingId = _computeListingId(collection, id, price, nonce);

        // Reverts if the listing does not exist by checking the owner (i.e. token holder) balance
        if (balanceOf[seller][listingId] == 0) revert InvalidListing();

        // Reverts if msg.value does not equal price
        if (msg.value != price) revert InvalidAmount();

        // Calculate withheld amount
        uint256 withheld = msg.value.mulDivDown(
            WITHHELD_PERCENT,
            WITHHELD_PERCENT_BASE
        );

        // Set the listing proceeds amount claimable by the token holder
        listingProceeds[listingId] = ListingProceeds(
            msg.value.safeCastTo128(),
            withheld.safeCastTo128()
        );

        // Send NFT to the buyer after confirming sufficient ETH was sent
        // Reverts if invalid listing (i.e. contract no longer has the NFT)
        collection.safeTransferFrom(address(this), msg.sender, id);
    }
}
