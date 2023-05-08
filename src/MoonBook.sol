// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {MoonPage} from "src/MoonPage.sol";

contract MoonBook is Owned {
    // Paired with the collection address to compute the CREATE2 salt
    bytes12 public constant SALT_FRAGMENT = bytes12("JPAGE||EGAPJ");

    address public immutable pageImplementation;

    // ERC721 collections mapped to their MoonPage contracts
    mapping(ERC721 => address) public pages;

    error AlreadyCreated();

    constructor() Owned(msg.sender) {
        pageImplementation = address(new MoonPage());
    }

    function createPage(ERC721 collection) external returns (address page) {
        // Prevent pages from being re-deployed and overwritten
        if (pages[collection] != address(0)) revert AlreadyCreated();

        page = Clones.cloneDeterministic(
            pageImplementation,
            keccak256(abi.encodePacked(collection, SALT_FRAGMENT))
        );

        // Initialize minimal proxy with the owner and collection
        MoonPage(page).initialize(owner, collection);

        // Update the mapping to point the collection to its page
        pages[collection] = page;
    }
}
