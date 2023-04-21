// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {MoonStaker} from "src/MoonStaker.sol";

contract Moon is Owned, ERC20("Redeemable Token", "MOON", 18), ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address payable;

    // Maximum duration users must wait to redeem the full ETH value of MOON
    uint256 public constant MAX_REDEMPTION_DURATION = 28 days;

    // ETH staker contract
    ERC20 public staker;

    // Vault contract
    ERC4626 public vault;

    event SetStaker(address indexed msgSender, ERC20 staker);
    event SetVault(address indexed msgSender, ERC4626 vault);
    event DepositETH(address indexed msgSender, uint256 msgValue);
    event StakeETH(
        address indexed msgSender,
        uint256 balance,
        uint256 assets,
        uint256 shares
    );

    error InvalidAddress();
    error InvalidAmount();

    constructor(ERC20 _staker, ERC4626 _vault) Owned(msg.sender) {
        if (address(_staker) == address(0)) revert InvalidAddress();
        if (address(_vault) == address(0)) revert InvalidAddress();

        staker = _staker;
        vault = _vault;

        // Allow the vault to transfer stETH on this contract's behalf
        staker.safeApprove(address(_vault), type(uint256).max);
    }

    function setStaker(ERC20 _staker) external onlyOwner {
        if (address(_staker) == address(0)) revert InvalidAddress();

        address vaultAddr = address(vault);

        // Set the vault's allowance to zero for the previous staker
        staker.safeApprove(vaultAddr, 0);

        // Set the new staker
        staker = _staker;

        // Set the vault's allowance to the maximum for the current staker
        _staker.safeApprove(vaultAddr, type(uint256).max);

        emit SetStaker(msg.sender, _staker);
    }

    function setVault(ERC4626 _vault) external onlyOwner {
        if (address(_vault) == address(0)) revert InvalidAddress();

        // Set the previous vault's allowance to zero
        staker.safeApprove(address(vault), 0);

        // Set the new vault
        vault = _vault;

        // Set the new vault's allowance to the maximum
        staker.safeApprove(address(_vault), type(uint256).max);

        emit SetVault(msg.sender, _vault);
    }

    /**
     * @notice Deposit ETH, receive MOON
     */
    function depositETH() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();

        // Mint MOON for msg.sender, equal to the ETH deposited
        _mint(msg.sender, msg.value);

        emit DepositETH(msg.sender, msg.value);
    }

    /**
     * @notice Stake ETH
     * @return balance  uint256  ETH balance staked
     * @return assets   uint256  Vault assets deposited
     * @return shares   uint256  Vault shares received
     */
    function _stakeETH()
        private
        returns (uint256 balance, uint256 assets, uint256 shares)
    {
        balance = address(this).balance;

        // Stake ETH balance - reverts if msg.value is zero
        payable(address(staker)).safeTransferETH(balance);

        // Fetch staked ETH balance, the amount which will be deposited into the vault
        assets = staker.balanceOf(address(this));

        // Maximize returns with the staking vault - the Moon contract receives shares
        shares = vault.deposit(assets, address(this));

        emit StakeETH(msg.sender, balance, assets, shares);
    }

    /**
     * @notice Stake ETH
     * @return uint256  ETH balance staked
     * @return uint256  Vault assets deposited
     * @return uint256  Vault shares received
     */
    function stakeETH()
        external
        nonReentrant
        returns (uint256, uint256, uint256)
    {
        return _stakeETH();
    }
}
