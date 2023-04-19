// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract Moon is ERC20("Redeemable Token", "MOON", 18) {
    using SafeTransferLib for address payable;

    // Lido stETH proxy contract address
    address payable public constant LIDO =
        payable(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    address public immutable protocolTeam;

    event DepositETH(address indexed msgSender, uint256 msgValue);

    error InvalidAddress();
    error InvalidAmount();

    constructor(address _protocolTeam) {
        if (_protocolTeam == address(0)) revert InvalidAddress();

        protocolTeam = _protocolTeam;
    }

    /**
     * @notice Deposit ETH, receive MOON
     */
    function depositETH() external payable {
        if (msg.value == 0) revert InvalidAmount();

        // Stake ETH in Lido
        LIDO.safeTransferETH(msg.value);

        // Mint MOON for msg.sender, equal to the ETH received
        _mint(msg.sender, msg.value);

        emit DepositETH(msg.sender, msg.value);
    }
}
