// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";

interface ILido {
    function submit(address _referral) external payable returns (uint256);
}

contract Moon is ERC20("Redeemable Token", "MOON", 18) {
    // Lido stETH proxy contract address
    ILido public constant LIDO =
        ILido(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    address payable public immutable protocolTeam;

    event DepositETH(
        address indexed msgSender,
        uint256 msgValue,
        uint256 staked
    );

    error InvalidAddress();
    error InvalidAmount();

    constructor(address payable _protocolTeam) {
        if (_protocolTeam == address(0)) revert InvalidAddress();

        protocolTeam = _protocolTeam;
    }

    /**
     * @notice Deposit ETH, receive MOON
     */
    function depositETH() external payable {
        if (msg.value == 0) revert InvalidAmount();

        // Stake ETH in Lido
        uint256 staked = LIDO.submit{value: msg.value}(address(0));

        // Mint MOON for msg.sender, equal to the stETH received
        _mint(msg.sender, staked);

        emit DepositETH(msg.sender, msg.value, staked);
    }
}
