// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {MoonBook} from "src/MoonBook.sol";
import {Moon} from "src/Moon.sol";

contract MoonBookFactory {
    Moon public immutable moon;

    // NFT collections mapped to their order books
    mapping(ERC721 collection => address book) public books;

    event CreateBook(
        address indexed caller,
        address indexed book,
        ERC721 indexed collection
    );

    error InvalidAddress();
    error AlreadyExists();

    constructor(Moon _moon) {
        if (address(_moon) == address(0)) revert InvalidAddress();

        moon = _moon;
    }

    function createBook(ERC721 collection) external {
        // Check if the collection already has a MoonBook deployed for it
        if (books[collection] != address(0)) revert AlreadyExists();

        // Deploy and associate collection with a MoonBook contract
        // TODO: Consider minimal proxy usage for gas efficiency
        address book = address(new MoonBook(collection, moon));

        // Add to list of factory-owned books
        books[collection] = book;

        // Enable the MoonBook contract to mint MOON rewards
        moon.addMinter(book);

        emit CreateBook(msg.sender, book, collection);
    }
}
