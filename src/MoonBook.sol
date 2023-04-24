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

    error InvalidAddress();
    error InvalidAmount();
    error OnlySeller();

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
     * @param  id     uint256  NFT ID
     * @param  price  uint96   NFT price in ETH
     */
    function list(uint256 id, uint96 price) external nonReentrant {
        // Reverts if the NFT is not owned by msg.sender
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Set listing details
        collectionListings[id] = Listing(msg.sender, price);
    }

    /**
     * @notice List many NFTs for sale
     * @param  ids     uint256[]  NFT IDs
     * @param  prices  uint96[]   NFT prices in ETH
     */
    function listMany(
        uint256[] calldata ids,
        uint96[] calldata prices
    ) external nonReentrant {
        uint256 iLen = ids.length;

        // Loop body does not execute if iLen is zero, and tx reverts if the
        // `ids` and `prices` arrays are mismatched in terms of length
        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];

            // Reverts if the NFT is not owned by msg.sender
            collection.safeTransferFrom(msg.sender, address(this), id);

            // Set listing details
            collectionListings[id] = Listing(msg.sender, prices[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Edit NFT listing price
     * @param  id        uint256  NFT ID
     * @param  newPrice  uint96   New NFT price
     */
    function editListing(uint256 id, uint96 newPrice) external {
        Listing storage listing = collectionListings[id];

        // msg.sender must be the listing seller, otherwise they cannot edit
        if (listing.seller != msg.sender) revert OnlySeller();

        listing.price = newPrice;
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
    }

    /**
     * @notice Buy a NFT
     * @param  id  uint256  NFT ID
     */
    function buy(uint256 id) external payable nonReentrant {
        Listing memory listing = collectionListings[id];

        // Reverts if msg.value does not equal listing price
        if (msg.value != listing.price) revert InvalidAmount();

        // Delete listing before exchanging tokens
        delete collectionListings[id];

        // Send NFT to the buyer after confirming sufficient ETH was sent
        // Reverts if invalid listing (i.e. contract no longer has the NFT)
        collection.safeTransferFrom(address(this), msg.sender, id);

        // Calculate protocol fees
        uint256 fees = listing.price.mulDivDown(
            MOON_FEE_PERCENT,
            MOON_FEE_PERCENT_BASE
        );

        // Transfer the post-fee sale proceeds to the seller
        payable(listing.seller).safeTransferETH(listing.price - fees);

        // Deposit fees into the protocol contract, and distribute MOON rewards to the
        // seller (equal to the ETH fees they've paid)
        moon.depositETH{value: fees}(listing.seller);
    }
}
