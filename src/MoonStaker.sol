// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface UserModule {
    function deposit(uint256, address) external returns (uint256);
}

contract MoonStaker {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address payable;

    // Lido stETH proxy contract address
    ERC20 public constant LIDO =
        ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    // Instadapp proxy contract address
    UserModule public constant INSTADAPP =
        UserModule(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);

    address public immutable moon;

    error InvalidAddress();
    error OnlyMoon();

    constructor(address _moon) {
        if (_moon == address(0)) revert InvalidAddress();

        moon = _moon;

        // Enables Instadapp to transfer stETH on our behalf when depositing
        LIDO.safeApprove(address(INSTADAPP), type(uint256).max);
    }

    function stakeETH()
        external
        payable
        returns (uint256 assets, uint256 shares)
    {
        if (msg.sender != moon) revert OnlyMoon();

        // Stake ETH balance with Lido - reverts if msg.value is zero
        payable(address(LIDO)).safeTransferETH(msg.value);

        // Fetch stETH balance, the amount which will be deposited into the vault
        assets = LIDO.balanceOf(address(this));

        // Maximize returns with the Instadapp vault - moon receives shares
        shares = INSTADAPP.deposit(assets, moon);
    }
}
