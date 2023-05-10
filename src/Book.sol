// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {Page} from "src/Page.sol";

contract Book is Owned {
    // Paired with the collection address to compute the CREATE2 salt
    bytes12 public constant SALT_FRAGMENT = bytes12("JPAGE||EGAPJ");

    // Page implementation contract address
    address public immutable pageImplementation;

    // ERC721 collections mapped to their Page contracts
    mapping(ERC721 => address) public pages;

    error Invalid();
    error AlreadyExists();

    constructor() Owned(msg.sender) {
        pageImplementation = address(new Page());
    }

    function createPage(ERC721 collection) external returns (address page) {
        // Revert if the collection is the zero address
        if (address(collection) == address(0)) revert Invalid();

        // Prevent pages from being re-deployed and overwritten
        if (pages[collection] != address(0)) revert AlreadyExists();

        page = Clones.cloneDeterministic(
            pageImplementation,
            keccak256(abi.encodePacked(collection, SALT_FRAGMENT))
        );

        // Initialize minimal proxy with the owner and collection
        Page(page).initialize(owner, collection);

        // Update the mapping to point the collection to its page
        pages[collection] = page;
    }
}
