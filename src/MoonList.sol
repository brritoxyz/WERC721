// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {MoonPage} from "src/MoonPage.sol";

contract MoonPageExchange is MoonPage {
    using SafeTransferLib for address payable;

    struct Listing {
        address seller;
        uint96 price;
    }

    mapping(uint256 => Listing) public listings;

    event List(uint256 indexed id, address indexed seller, uint96 price);
    event Edit(uint256 indexed id, address indexed seller, uint96 newPrice);
    event Cancel(uint256 indexed id, address indexed seller);
    event Buy(
        uint256 indexed id,
        address indexed buyer,
        address indexed seller,
        uint96 price
    );

    error Unauthorized();
    error Nonexistent();
    error Insufficient();

    constructor() {}

    /**
     * @notice Create a listing
     * @param  id     uint256  Collection token ID
     * @param  price  uint96   Price
     */
    function list(uint256 id, uint96 price) external {
        // Reverts if msg.sender does not have the token
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Update token owner to this contract to prevent double-listing
        ownerOf[id] = address(this);

        // Set the listing
        listings[id] = Listing(msg.sender, price);

        emit List(id, msg.sender, price);
    }

    /**
     * @notice Edit a listing
     * @param  id        uint256  Collection token ID
     * @param  newPrice  uint96   New price
     */
    function edit(uint256 id, uint96 newPrice) external {
        Listing storage listing = listings[id];

        // Reverts if msg.sender is not the seller
        if (listing.seller != msg.sender) revert Unauthorized();

        // Update the listing price
        listing.price = newPrice;

        emit Edit(id, msg.sender, newPrice);
    }

    /**
     * @notice Cancel a listing
     * @param  id  uint256  Collection token ID
     */
    function cancel(uint256 id) external {
        // Reverts if msg.sender is not the seller
        if (listings[id].seller != msg.sender) revert Unauthorized();

        // Delete listing prior to returning the token
        delete listings[id];

        ownerOf[id] = msg.sender;

        emit Cancel(id, msg.sender);
    }

    /**
     * @notice Cancel a listing
     * @param  id  uint256  Collection token ID
     */
    function buy(uint256 id) external payable nonReentrant {
        Listing memory listing = listings[id];

        // Reverts if the listing does not exist
        if (listing.seller == address(0)) revert Nonexistent();

        // Reverts if the msg.value does not cover the price
        if (msg.value != listing.price) revert Insufficient();

        // Delete listing prior to returning the token
        delete listings[id];

        // Set the new token owner to the buyer
        ownerOf[id] = msg.sender;

        // Transfer ETH to the seller
        payable(listing.seller).safeTransferETH(msg.value);

        emit Buy(id, msg.sender, listing.seller, listing.price);
    }
}
