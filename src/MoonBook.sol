// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Moon} from "src/Moon.sol";

contract MoonBook is ERC721TokenReceiver, ReentrancyGuard {
    using FixedPointMathLib for uint96;
    using SafeTransferLib for address payable;

    struct Listing {
        // NFT seller, receives ETH upon sale
        address seller;
        // Denominated in ETH
        uint96 price;
    }

    // Fees are 1%
    uint128 public constant MOON_FEE_PERCENT = 1;

    // Used for calculating fees
    uint128 public constant MOON_FEE_PERCENT_BASE = 100;

    // MOON token contract
    Moon public immutable moon;

    // NFT collection contract
    ERC721 public immutable collection;

    // NFT collection listings
    mapping(uint256 id => Listing listing) public collectionListings;

    event List(
        address indexed msgSender,
        uint256 indexed id,
        address indexed seller,
        uint96 price
    );
    event EditListing(
        address indexed msgSender,
        uint256 indexed id,
        address indexed newSeller,
        uint96 newPrice
    );
    event CancelListing(address indexed msgSender, uint256 indexed id);
    event Buy(
        address indexed msgSender,
        uint256 indexed id,
        address indexed recipient
    );

    error InvalidAddress();
    error InvalidPrice();
    error OnlySeller();
    error InsufficientFunds();

    /**
     * @param _moon        Moon    Moon protocol contract
     * @param _collection  ERC721  NFT collection contract
     */
    constructor(Moon _moon, ERC721 _collection) {
        if (address(_moon) == address(0)) revert InvalidAddress();
        if (address(_collection) == address(0)) revert InvalidAddress();

        moon = _moon;
        collection = _collection;
    }

    /**
     * @notice List a NFT for sale
     * @param  id      uint256  NFT ID
     * @param  seller  address  NFT seller
     * @param  price   uint96   NFT price in ETH
     */
    function list(
        uint256 id,
        address seller,
        uint96 price
    ) external nonReentrant {
        if (seller == address(0)) revert InvalidAddress();
        if (price == 0) revert InvalidPrice();

        // Reverts if the NFT is not owned by msg.sender
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Set listing details
        collectionListings[id] = Listing(seller, price);

        emit List(msg.sender, id, seller, price);
    }

    /**
     * @notice Edit NFT listing seller and/or price
     * @param  id         uint256  NFT ID
     * @param  newSeller  address  New NFT seller
     * @param  newPrice   uint96   New NFT price
     */
    function editListing(
        uint256 id,
        address newSeller,
        uint96 newPrice
    ) external {
        if (newSeller == address(0)) revert InvalidAddress();
        if (newPrice == 0) revert InvalidPrice();

        Listing storage listing = collectionListings[id];

        // msg.sender must be the listing seller, otherwise they cannot edit
        if (listing.seller != msg.sender) revert OnlySeller();

        listing.seller = newSeller;
        listing.price = newPrice;

        emit EditListing(msg.sender, id, newSeller, newPrice);
    }

    /**
     * @notice Cancel NFT listing and reclaim NFT
     * @param  id  uint256  NFT ID
     */
    function cancelListing(uint256 id) external nonReentrant {
        // msg.sender must be the listing seller, otherwise they cannot cancel
        if (collectionListings[id].seller != msg.sender) revert OnlySeller();

        delete collectionListings[id];

        // Return the NFT to the seller
        collection.safeTransferFrom(address(this), msg.sender, id);

        emit CancelListing(msg.sender, id);
    }

    /**
     * @notice Buy a single NFT
     * @param  id         uint256  NFT ID
     * @param  recipient  address  NFT recipient
     */
    function buy(uint256 id, address recipient) external payable nonReentrant {
        if (recipient == address(0)) revert InvalidAddress();

        Listing memory listing = collectionListings[id];

        // Reverts if msg.value does not equal listing price, or if listing is non-existent
        if (msg.value != listing.price) revert InsufficientFunds();

        // Delete listing before exchanging tokens
        delete collectionListings[id];

        // Send NFT to the recipient after confirming sufficient ETH was sent by msg.sender
        collection.safeTransferFrom(address(this), recipient, id);

        // Calculate protocol fees
        uint256 fees = listing.price.mulDivDown(
            MOON_FEE_PERCENT,
            MOON_FEE_PERCENT_BASE
        );

        // Transfer the post-fee sale proceeds to the seller
        payable(listing.seller).safeTransferETH(listing.price - fees);

        // Deposit fees into the protocol contract, and distribute MOON rewards to both the
        // buyer (i.e. recipient) and seller, equal to the ETH fees paid
        moon.depositFees{value: fees}(recipient, listing.seller);

        emit Buy(msg.sender, id, recipient);
    }
}
