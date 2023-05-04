// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Moon} from "src/Moon.sol";

contract MoonBook is ERC721TokenReceiver, Moon {
    using SafeTransferLib for address payable;
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint96;

    struct Listing {
        // NFT seller, receives ETH upon sale
        address seller;
        // Denominated in ETH
        uint96 price;
    }

    // 1% of proceeds are withheld and can be redeemed later
    uint128 public constant WITHHELD_PERCENT = 1;

    // Used for calculating fees
    uint128 public constant WITHHELD_PERCENT_BASE = 100;

    // NFT listings
    mapping(ERC721 collection => mapping(uint256 id => Listing listing))
        public listings;

    error OnlySeller();

    constructor(address _staker, address _vault) Moon(_staker, _vault) {}

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
}
