// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface IUserModule {
    function deposit(uint256, address) external returns (uint256);

    function withdraw(uint256, address, address) external returns (uint256);

    function maxWithdraw(address) external view returns (uint256);
}

contract MoonStaker {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address payable;

    // Lido stETH proxy contract address
    ERC20 public constant LIDO =
        ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    // Vault proxy contract address
    IUserModule public constant VAULT =
        IUserModule(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);

    address public immutable moon;

    error InvalidAddress();
    error OnlyMoon();

    constructor(address _moon) {
        if (_moon == address(0)) revert InvalidAddress();

        moon = _moon;

        // Enables the vault to transfer stETH on our behalf when depositing
        LIDO.safeApprove(address(VAULT), type(uint256).max);
    }

    modifier onlyMoon() {
        if (msg.sender != moon) revert OnlyMoon();
        _;
    }

    /**
     * @notice Fetch the total assets deposited in the vault
     * @return uint256  Vault assets
     */
    function totalAssets() external view returns (uint256) {
        return VAULT.maxWithdraw(moon);
    }

    /**
     * @notice Stake ETH
     * @return assets  uint256  Vault assets deposited
     * @return shares  uint256  Vault shares minted
     */
    function stakeETH()
        external
        payable
        onlyMoon
        returns (uint256 assets, uint256 shares)
    {
        // Stake ETH balance with Lido - reverts if msg.value is zero
        payable(address(LIDO)).safeTransferETH(msg.value);

        // Fetch stETH balance, the amount which will be deposited into the vault
        assets = LIDO.balanceOf(address(this));

        // Maximize returns with the staking vault - the Moon contract receives shares
        shares = VAULT.deposit(assets, moon);
    }

    /**
     * @notice Stake ETH
     * @param  assets     uint256  Vault assets withdrawn
     * @param  recipient  address  MOON redeemer
     * @return            uint256  Vault shares redeemed
     */
    function unstakeETH(
        uint256 assets,
        address recipient
    ) external onlyMoon returns (uint256) {
        // Withdraw assets for the Moon contract with the MOON redeemer as the recipient
        return VAULT.withdraw(assets, recipient, moon);
    }
}
