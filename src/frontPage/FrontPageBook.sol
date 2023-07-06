// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Book} from "src/Book.sol";

contract FrontPageBook is Book {
    // Current ERC-721 collection implementation version
    uint256 public currentCollectionVersion;

    // Version numbers mapped to ERC-721 collection implementation addresses
    mapping(uint256 => address) public collectionImplementations;

    event UpgradeCollection(uint256 version, address implementation);

    /**
     * @notice Increment the version and deploy a new implementation to that version
     * @param  salt            bytes32  CREATE2 salt
     * @param  bytecode        bytes    New ERC-721 contract init code
     * @return version         uint256  New version
     * @return implementation  address  New ERC-721 contract implementation address
     */
    function upgradeCollection(
        bytes32 salt,
        bytes memory bytecode
    )
        external
        payable
        onlyOwner
        returns (uint256 version, address implementation)
    {
        implementation = _create2(salt, bytecode);

        // Increment the current version number - overflow is unrealistic since
        // the cost would be exorbitant for the contract owner, even on an L2
        unchecked {
            version = ++currentCollectionVersion;
        }

        collectionImplementations[version] = implementation;

        emit UpgradeCollection(version, implementation);
    }
}
