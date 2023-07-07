// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clone} from "solady/utils/Clone.sol";
import {PageExchange} from "src/PageExchange.sol";

contract BackPage is Clone, PageExchange {
    // Fixed clone immutable arg byte offsets
    uint256 private constant IMMUTABLE_ARG_OFFSET_COLLECTION = 0;

    bool private _initialized;

    error AlreadyInitialized();

    constructor() payable {
        // Prevent the implementation from being initialized
        _initialized = true;
    }

    /**
     * @notice Initializes the minimal proxy contract storage
     */
    function initialize() external {
        if (_initialized) revert AlreadyInitialized();

        // Prevent initialize from being called again
        _initialized = true;

        // Initialize `locked` with the value of 1 (i.e. unlocked)
        locked = 1;
    }

    function collection() public pure override returns (address) {
        return _getArgAddress(IMMUTABLE_ARG_OFFSET_COLLECTION);
    }
}
