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
    error Create2Failed();

    // Removes opcodes for checking whether msg.value is non-zero during deployment
    constructor() payable {
        _initializeOwner(msg.sender);
    }

    /**
     * @notice Deploy an implementation contract using the CREATE2 opcode
     * @notice This method can be reused by derived contracts for different implementation types
     * @param  salt            bytes32  Salt
     * @param  bytecode        bytes    Contract init code
     * @return implementation  address  New contract address
     */
    function _create2(
        bytes32 salt,
        bytes memory bytecode
    ) internal returns (address implementation) {
        if (bytecode.length == 0) revert EmptyBytecode();

        assembly {
            implementation := create2(
                callvalue(),
                add(bytecode, 0x20),
                mload(bytecode),
                salt
            )
        }

        // Revert if the deployment failed (e.g. previously-used bytecode and salt)
        if (implementation == address(0)) revert Create2Failed();
    }

    /**
     * @notice Deploy a new, versioned page implementation contract
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
        // Deploy the new implementation contract
        implementation = _create2(salt, bytecode);

        // Increment the current version number - overflow is unrealistic since
        // the cost would be exorbitant for the contract owner, even on an L2
        unchecked {
            version = ++currentVersion;
        }

        // Map the new version to the new implementation address
        pageImplementations[version] = implementation;

        emit UpgradePage(version, implementation);
    }
}
