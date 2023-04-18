// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract Moon is ERC20("Redeemable Token", "MOON", 18) {
    address payable public immutable protocolTeam;

    event DepositETH(address indexed depositor, uint256 amount);

    error InvalidAddress();
    error InvalidAmount();

    constructor(address payable _protocolTeam) {
        if (_protocolTeam == address(0)) revert InvalidAddress();

        protocolTeam = _protocolTeam;
    }

    /**
     * @notice Deposit ETH for MOON
     */
    function depositETH() external payable {
        if (msg.value == 0) revert InvalidAmount();

        // Mint MOON for msg.sender, equal to the ETH amount deposited
        _mint(msg.sender, msg.value);

        emit DepositETH(msg.sender, msg.value);
    }
}
