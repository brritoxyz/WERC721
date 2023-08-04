// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {WERC721} from "src/WERC721.sol";

/**
 * @title ERC721 wrapper factory contract.
 * @notice Deploy a WERC721.sol contract for any ERC721 collection.
 * @author kp (ppmoon69.eth)
 * @custom:contributor vectorized (vectorized.eth)
 * @custom:contributor pashov (pashov.eth)
 */
contract WERC721Factory {
    // Wrapped collection (i.e. WERC721) implementation address.
    WERC721 public immutable implementation = new WERC721();

    // Collection contracts mapped to their wrapped counterparts.
    mapping(ERC721 collection => WERC721 wrapper) public wrappers;

    // This emits when a new WERC721 contract is created.
    event CreateWrapper(ERC721 indexed collection, WERC721 indexed wrapper);

    error InvalidCollectionAddress();
    error WrapperAlreadyCreated();

    /**
     * @notice Create a new WERC721 contract.
     * @param  collection  ERC721   ERC721 collection contract.
     * @return wrapper     WERC721  Wrapped ERC721 contract (clone with immutable args).
     */
    function create(ERC721 collection) external returns (WERC721 wrapper) {
        if (address(collection) == address(0))
            revert InvalidCollectionAddress();

        // Each collection should only have one WERC721 contract to avoid confusion.
        if (address(wrappers[collection]) != address(0))
            revert WrapperAlreadyCreated();

        // Clone the implementation with `collection` stored as an immutable arg.
        wrapper = WERC721(
            LibClone.clone(
                address(implementation),
                abi.encodePacked(address(collection))
            )
        );

        // Prevent another WERC721 contract from being deployed for the collection.
        wrappers[collection] = wrapper;

        emit CreateWrapper(collection, wrapper);
    }
}
