// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Book} from "src/Book.sol";

interface IPage {
    function initialize() external;
}

contract BackPageBook is Book {
    // Paired with the collection address to compute the CREATE2 salt
    bytes32 public constant SALT_FRAGMENT = "JPAGE||EGAPJ";

    // Page implementations mapped to their ERC721 collections and associated BackPage contracts
    mapping(address => mapping(ERC721 => address)) public pages;

    event CreatePage(
        address indexed implementation,
        ERC721 indexed collection,
        address page
    );

    error ZeroAddress();
    error InvalidVersion();

    /**
     * @notice Creates a new clone for the collection and implementation version
     * @param  collection  ERC721   NFT collection
     * @param  version     uint256  Page implementation version
     * @return page        address  Page contract address
     */
    function createPage(
        ERC721 collection,
        uint256 version
    ) external payable returns (address page) {
        // Revert if the collection is the zero address
        if (address(collection) == address(0)) revert ZeroAddress();

        address implementation = pageImplementations[version];

        // Revert if there is no implementation for the given version
        if (implementation == address(0)) revert InvalidVersion();

        // Create a minimal proxy for the implementation
        page = LibClone.cloneDeterministic(
            implementation,
            abi.encodePacked(address(collection)),
            keccak256(
                abi.encodePacked(collection, SALT_FRAGMENT, block.timestamp)
            )
        );

        // Only store pages if they don't already exist, otherwise, return the address and emit the
        // event in order to signify that a new Page contract was deployed. By enabling multiple, "non-canonical"
        // deployments, we're able to circumvent censorship by collections and actors such as OpenSea
        if (pages[implementation][collection] == address(0)) {
            // Update the mapping to point the collection to its page
            pages[implementation][collection] = page;
        }

        emit CreatePage(implementation, collection, page);

        // Initialize the minimal proxy's state variables
        IPage(page).initialize();
    }
}
