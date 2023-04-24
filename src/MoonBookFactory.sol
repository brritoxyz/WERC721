// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {MoonBook} from "src/MoonBook.sol";
import {Moon} from "src/Moon.sol";

contract MoonBookFactory {
    Moon public immutable moon;

    // NFT collections mapped to their MoonBook contracts
    mapping(ERC721 collection => MoonBook book) public moonBooks;

    event CreateMoonBook(address indexed msgSender, ERC721 indexed collection);

    error InvalidAddress();
    error AlreadyExists();

    constructor(Moon _moon) {
        if (address(_moon) == address(0)) revert InvalidAddress();

        moon = _moon;
    }

    /**
     * @notice Deploy a MoonBook contract for a collection
     * @param  collection  ERC721    NFT collection contract
     * @return moonBook    MoonBook  MoonBook contract
     */
    function createMoonBook(
        ERC721 collection
    ) external returns (MoonBook moonBook) {
        // Check if the collection already has a MoonBook deployed for it
        if (address(moonBooks[collection]) != address(0))
            revert AlreadyExists();

        // Deploy and associate collection with a MoonBook contract
        // TODO: Consider minimal proxy usage for gas efficiency
        moonBook = new MoonBook(moon, collection);

        // Add to list of factory-owned books
        moonBooks[collection] = moonBook;

        emit CreateMoonBook(msg.sender, collection);
    }
}
