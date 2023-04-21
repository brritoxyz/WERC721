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
    using SafeTransferLib for ERC4626;
    using SafeTransferLib for address payable;

    // Maximum duration users must wait to redeem the full ETH value of MOON
    uint256 public constant MAX_REDEMPTION_DURATION = 28 days;

    // For calculating the instant redemption amount
    uint256 public constant INSTANT_REDEMPTION_VALUE_BASE = 100;

    // ETH staker contract
    ERC20 public staker;

    // Vault contract
    ERC4626 public vault;

    // Instant redemptions enable users to redeem their ETH rebates immediately
    // by giving up a portion of MOON. The default instant redemption value is
    // 75% of the redeemed MOON amount so it's better for users to wait
    uint256 public instantRedemptionValue = 75;

    mapping(address => mapping(uint256 => uint256)) public pendingRedemptions;

    event SetStaker(address indexed msgSender, ERC20 staker);
    event SetVault(address indexed msgSender, ERC4626 vault);
    event SetInstantRedemptionValue(
        address indexed msgSender,
        uint256 instantRedemptionValue
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

    function setInstantRedemptionValue(
        uint256 _instantRedemptionValue
    ) external onlyOwner {
        if (_instantRedemptionValue > INSTANT_REDEMPTION_VALUE_BASE)
            revert InvalidAmount();

        // Set the new instantRedemptionValue
        instantRedemptionValue = _instantRedemptionValue;

        emit SetInstantRedemptionValue(msg.sender, _instantRedemptionValue);
    }

    /**
     * @notice Deposit ETH, receive MOON
     */
    function depositETH() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();

        // Mint MOON for msg.sender, equal to the ETH deposited
        _mint(msg.sender, msg.value);
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

        // Only execute ETH-staking functions if the ETH balance is non-zero
        if (balance != 0) {
            // Stake ETH balance - reverts if msg.value is zero
            payable(address(staker)).safeTransferETH(balance);

            // Fetch staked ETH balance, the amount which will be deposited into the vault
            assets = staker.balanceOf(address(this));

            // Maximize returns with the staking vault - the Moon contract receives shares
            shares = vault.deposit(assets, address(this));
        }
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

    /**
     * @notice Instantly redeem MOON for the underlying assets at 50% of the value
     * @param  amount    uint256  MOON amount
     */
    function instantlyRedeemMOON(
        uint256 amount
    ) external nonReentrant returns (uint256 redeemed, uint256 shares) {
        if (amount == 0) revert InvalidAmount();

        // NOTE: Due to rounding, the redeemed amount will be zero if `amount` < 2!
        // The remainder of the function logic assumes that the caller is a logical actor
        // since redeeming extremely small amounts of MOON is uneconomical due to gas fees
        redeemed = amount.mulDivDown(
            instantRedemptionValue,
            INSTANT_REDEMPTION_VALUE_BASE
        );

        // Stake ETH first to ensure that the contract's vault share balance is current
        _stakeETH();

        // Calculate the amount of vault shares redeemed - based on the proportion of
        // the redeemed MOON amount to the total MOON supply
        shares = vault.balanceOf(address(this)).mulDivDown(
            redeemed,
            totalSupply
        );

        // Burn MOON from msg.sender - reverts if their balance is insufficient
        _burn(msg.sender, amount);

        // Mint MOON for the owner, equal to the unredeemed amount
        _mint(owner, amount - redeemed);

        // Transfer the redeemed amount to msg.sender (vault shares, as good as ETH)
        vault.safeTransfer(msg.sender, shares);
    }

    /**
     * @notice Begin a MOON redemption
     * @param  amount    uint256  MOON amount
     * @param  duration  uint256  Queue duration in seconds
     */
    function startRedeemMOON(
        uint256 amount,
        uint256 duration
    ) external nonReentrant returns (uint256 redeemed, uint256 shares) {
        if (amount == 0) revert InvalidAmount();
        if (duration == 0) revert InvalidAmount();
        if (duration > MAX_REDEMPTION_DURATION) revert InvalidAmount();

        // The redeemed amount is based on the total duration the user is willing
        // to wait for their redemption to complete (waiting the max duration
        // results in 100% of the underlying ETH-based assets being redeemed)
        redeemed = amount.mulDivDown(duration, MAX_REDEMPTION_DURATION);

        // Stake ETH first to ensure that the contract's vault share balance is current
        _stakeETH();

        // Calculate the amount of vault shares redeemed - based on the proportion of
        // the redeemed MOON amount to the total MOON supply
        shares = vault.balanceOf(address(this)).mulDivDown(
            redeemed,
            totalSupply
        );

        // Burn MOON from msg.sender - reverts if their balance is insufficient
        _burn(msg.sender, amount);

        // If amount does not equal redeemed, then `duration` is less than the maximum
        if (amount != redeemed) {
            _mint(owner, amount - redeemed);
        }

        // Set the amount of shares that the user can claim after the duration has elapsed
        pendingRedemptions[msg.sender][block.timestamp + duration] += shares;
    }
}
