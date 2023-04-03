// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract MoonPool is ERC721TokenReceiver, Owned, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint96;
    using SafeTransferLib for address payable;

    struct Listing {
        // NFT seller, receives ETH upon sale
        address seller;
        // Denominated in ETH
        uint96 price;
    }

    // 10,000 basis points = 100%
    uint128 public constant FEE_BPS_BASE = 10_000;

    // Fees are 0.50%
    uint128 public constant FEE_BPS = 50;

    // NFT collection contract
    ERC721 public immutable collection;

    // NFT collection listings
    mapping(uint256 id => Listing listing) public collectionListings;

    // NFT collection offers (ID agnostic)
    mapping(uint256 offer => address[] buyers) public collectionOffers;

    // Protocol fees are charged upon each exchange and results in...
    // MOON rewards being minted for both the seller and the buyer
    address payable public feeRecipient;

    event SetFeeRecipient(address indexed feeRecipient);
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
        uint256 totalFees
    );
    event MakeOffer(address indexed buyer, uint256 offer);
    event CancelOffer(address indexed buyer, uint256 offer);
    event TakeOffer(
        address indexed seller,
        address indexed buyer,
        uint256 id,
        uint256 offer
    );

    error InvalidAddress();
    error InvalidPrice();
    error InvalidOffer();
    error EmptyArray();
    error MismatchedArrays();
    error InsufficientFunds();
    error NotSeller();
    error NotBuyer();
    error ZeroValue();

    /**
     * @param _owner       address  Contract owner (can set fee recipient only)
     * @param _collection  ERC721   NFT collection contract
     */
    constructor(address _owner, ERC721 _collection) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
        if (address(_collection) == address(0)) revert InvalidAddress();

        collection = _collection;
    }

    /**
     * @notice Set fee recipient
     * @param  _feeRecipient  address  Fee recipient address
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert InvalidAddress();

        feeRecipient = payable(_feeRecipient);

        emit SetFeeRecipient(_feeRecipient);
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
        if (price == 0) revert InvalidPrice();

        // Reverts if the NFT is not owned by msg.sender
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Set listing details
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

            // Reverts if the NFT is not owned by msg.sender
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

        // Return the NFT to the seller
        collection.safeTransferFrom(address(this), msg.sender, id);

        emit CancelListing(msg.sender, id);
    }

    /**
     * @notice Edit NFT listing price
     * @param  id     uint256  NFT ID
     * @param  price  uint96   NFT price
     */
    function editListing(uint256 id, uint96 price) external nonReentrant {
        if (price == 0) revert InvalidPrice();

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
     * @param  id  uint256  NFT ID
     */
    function buy(uint256 id) external payable nonReentrant {
        Listing memory listing = collectionListings[id];

        if (msg.value != listing.price) revert InsufficientFunds();

        // Delete listing before exchanging tokens
        delete collectionListings[id];

        // Send NFT to buyer after confirming sufficient ETH was sent
        collection.safeTransferFrom(address(this), msg.sender, id);

        // Calculate protocol fees
        uint256 fees = listing.price.mulDivDown(FEE_BPS, FEE_BPS_BASE);

        // Transfer protocol fees to fee recipient
        feeRecipient.safeTransferETH(fees);

        // Transfer the post-fee sale proceeds to the seller
        payable(listing.seller).safeTransferETH(listing.price - fees);

        emit Buy(msg.sender, listing.seller, id, listing.price, fees);
    }

    /**
     * @notice Buy many NFTs
     * @param  ids  uint256[]  NFT IDs
     */
    function buyMany(uint256[] calldata ids) external payable nonReentrant {
        uint256 iLen = ids.length;

        if (iLen == 0) revert EmptyArray();

        // Track the total price of all NFTs purchased to confirm sufficient ETH was sent
        uint256 totalPrice;

        // Track the total fees accrued to pay the fee recipient at the end of this call
        uint256 totalFees;

        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];
            Listing memory listing = collectionListings[id];

            // Check whether the buyer has enough ETH to cover all of the NFTs purchased
            if (msg.value < (totalPrice += listing.price))
                revert InsufficientFunds();

            delete collectionListings[id];

            // Send NFT to buyer after verifying that they have enough ETH
            collection.safeTransferFrom(address(this), msg.sender, id);

            // Enables us to calculate the post-fee ETH amount to transfer to the seller
            uint256 fees = listing.price.mulDivDown(FEE_BPS, FEE_BPS_BASE);

            // Accrue total fees and do a single payment at the end of this call
            totalFees += fees;

            // Transfer the listing proceeds minus the fees to the seller
            payable(listing.seller).safeTransferETH(listing.price - fees);

            // Will not overflow since it's bound by the `ids` array's length
            unchecked {
                ++i;
            }
        }

        // Pay protocol fees in a single batched transfer
        feeRecipient.safeTransferETH(totalFees);

        emit BuyMany(msg.sender, ids, totalPrice, totalFees);
    }

    /*///////////////////////////////////////////////////////////////
                            Offer Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Make an offer for a single NFT
     */
    function makeOffer() external payable nonReentrant {
        if (msg.value == 0) revert ZeroValue();

        // User offer is the amount of ETH sent with the transaction
        collectionOffers[msg.value].push(msg.sender);

        emit MakeOffer(msg.sender, msg.value);
    }

    /**
     * @notice Cancel offer and reclaim ETH
     * @param  offer       uint256  Offer amount
     * @param  buyerIndex  uint256  Buyer index
     */
    function cancelOffer(
        uint256 offer,
        uint256 buyerIndex
    ) external nonReentrant {
        // Only the buyer can cancel their own offer
        if (collectionOffers[offer][buyerIndex] != msg.sender)
            revert NotBuyer();

        // Delete offer prior to transferring ETH to the buyer
        delete collectionOffers[offer][buyerIndex];

        // Return ETH to the offer maker
        payable(msg.sender).safeTransferETH(offer);

        emit CancelOffer(msg.sender, offer);
    }

    /**
     * @notice Take offer
     * @param  id          uint256  NFT ID
     * @param  offer       uint256  Offer amount
     * @param  buyerIndex  uint256  Buyer index
     */
    function takeOffer(
        uint256 id,
        uint256 offer,
        uint256 buyerIndex
    ) external nonReentrant {
        address buyer = collectionOffers[offer][buyerIndex];

        // Revert if offer does not exist
        if (buyer == address(0)) revert InvalidOffer();

        // Remove the offer prior to exchanging tokens between buyer and seller
        delete collectionOffers[offer][buyerIndex];

        // Transfer NFT to the buyer - reverts if msg.sender does not have the NFT
        collection.safeTransferFrom(msg.sender, buyer, id);

        uint256 fees = offer.mulDivDown(FEE_BPS, FEE_BPS_BASE);

        // Transfer protocol fees to fee recipient
        feeRecipient.safeTransferETH(fees);

        // Transfer the post-fee sale proceeds to the seller
        payable(msg.sender).safeTransferETH(offer - fees);

        emit TakeOffer(msg.sender, buyer, id, offer);
    }
}
