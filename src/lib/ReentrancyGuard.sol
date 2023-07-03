// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

/// @notice Modified to enable initialization of `locked` (by derived contracts) by changing its visibility from `private` to `internal`
/// @notice Modified to replace `require` statement with `if` conditional and custom Reentrancy error
/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
contract ReentrancyGuard {
    uint256 internal locked = 1;

    error Reentrancy();

    modifier nonReentrant() {
        if (locked != 1) revert Reentrancy();

        locked = 2;

        _;

        locked = 1;
    }
}
