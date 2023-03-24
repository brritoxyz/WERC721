// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract MoonToken is Owned, ERC20("MoonBase", "MOON", 18) {
    address public router;

    event SetRouter(address);

    error InvalidAddress();

    constructor(address _owner) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
    }

    function setRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert InvalidAddress();

        router = _router;

        emit SetRouter(_router);
    }
}
