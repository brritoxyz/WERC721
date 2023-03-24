// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract MoonToken is Owned, ERC20("MoonBase", "MOON", 18) {
    address public router;
    mapping(address user => uint256 amount) public mintable;

    event SetRouter(address);
    event IncreaseMintable(address, uint256);

    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();

    constructor(address _owner) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
    }

    modifier onlyRouter() {
        if (msg.sender != router) revert Unauthorized();
        _;
    }

    function setRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert InvalidAddress();

        router = _router;

        emit SetRouter(_router);
    }

    function increaseMintable(address to, uint256 amount) external onlyRouter {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        mintable[to] += amount;

        emit IncreaseMintable(to, amount);
    }

    function mint() external {
        uint256 amount = mintable[msg.sender];

        if (amount == 0) revert InvalidAmount();

        mintable[msg.sender] = 0;

        _mint(msg.sender, amount);
    }
}
