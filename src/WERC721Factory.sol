// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {WERC721} from "src/WERC721.sol";

contract WERC721Factory {
    // Wrapped collection (i.e. WERC721) implementation address.
    WERC721 public immutable implementation;

    // Collection contracts mapped to their wrapped counterparts.
    mapping(ERC721 collection => WERC721 wrapper) public wrappers;

    event CreateWrapper(ERC721 indexed collection, WERC721 indexed wrapper);

    error InvalidCollectionAddress();
    error WrapperAlreadyCreated();

    constructor() {
        implementation = new WERC721();
    }

    /**
     * @notice Create a new WERC721 contract.
     * @param  collection  ERC721   ERC-721 collection contract.
     * @return wrapper     WERC721  Wrapped ERC-721 contract (clone with immutable args).
     */
    function create(ERC721 collection) external returns (WERC721 wrapper) {
        // Throws if the collection address is the zero address.
        if (address(collection) == address(0))
            revert InvalidCollectionAddress();

        // Throws if the wrapper contract already exists.
        if (address(wrappers[collection]) != address(0))
            revert WrapperAlreadyCreated();

        // Clone the implementation with `collection` stored as an immutable arg.
        wrapper = WERC721(
            LibClone.clone(
                address(implementation),
                abi.encodePacked(address(collection))
            )
        );

        // Store the collection and wrapper contract addresses.
        wrappers[collection] = wrapper;

        emit CreateWrapper(collection, wrapper);
    }
}
