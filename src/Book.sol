// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";

contract Book is Ownable {
    // Current page implementation version
    uint256 public currentVersion;

    // Version numbers mapped to page contract implementation addresses
    mapping(uint256 => address) public pageImplementations;

    event UpgradePage(uint256 version, address implementation);

    error EmptyBytecode();
    error Create2Duplicate();

    // Removes opcodes for checking whether msg.value is non-zero during deployment
    constructor() payable {
        _initializeOwner(msg.sender);
    }

    /**
     * @notice Increment the version and deploy a new implementation to that version
     * @param  salt            bytes32  CREATE2 salt
     * @param  bytecode        bytes    New Page contract init code
     * @return version         uint256  New version
     * @return implementation  address  New Page contract implementation address
     */
    function upgradePage(
        bytes32 salt,
        bytes memory bytecode
    )
        external
        payable
        onlyOwner
        returns (uint256 version, address implementation)
    {
        if (bytecode.length == 0) revert EmptyBytecode();

        // Increment the current version number - overflow is unrealistic since
        // the cost would be exorbitant for the contract owner, even on an L2
        unchecked {
            version = ++currentVersion;
        }

        assembly {
            implementation := create2(
                callvalue(),
                add(bytecode, 0x20),
                mload(bytecode),
                salt
            )
        }

        // Revert if the deployment failed (i.e. previously-used bytecode and salt)
        if (implementation == address(0)) revert Create2Duplicate();

        pageImplementations[version] = implementation;

        emit UpgradePage(version, implementation);
    }
}
