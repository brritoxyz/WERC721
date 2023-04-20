// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IUserModule} from "src/MoonStaker.sol";

interface IMoonStaker {
    function VAULT() external view returns (IUserModule);

    function stakeETH() external payable returns (uint256, uint256);

    function unstakeETH(
        uint256 assets,
        address recipient
    ) external returns (uint256);
}

contract Moon is Owned, ERC20("Redeemable Token", "MOON", 18), ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address payable;

    IMoonStaker public moonStaker;

    // Maximum duration users must wait to redeem the full ETH value of MOON
    uint256 public constant MAX_REDEMPTION_DURATION = 10 days;

    mapping(address user => mapping(uint256 redemptionTimestamp => uint256 amount))
        public redemptions;

    event SetMoonStaker(address indexed msgSender, IMoonStaker moonStaker);
    event DepositETH(address indexed msgSender, uint256 msgValue);
    event StakeETH(
        address indexed msgSender,
        uint256 balance,
        uint256 assets,
        uint256 shares
    );
    event InitiateRedemption(
        address indexed msgSender,
        uint256 amount,
        uint256 duration
    );

    error InvalidAddress();
    error InvalidAmount();
    error InvalidTimestamp();

    constructor() Owned(msg.sender) {}

    /**
     * @notice Set MoonStaker contract
     * @param  _moonStaker  MoonStaker  MoonStaker contract
     */
    function setMoonStaker(IMoonStaker _moonStaker) external onlyOwner {
        if (address(_moonStaker) == address(0)) revert InvalidAddress();

        if (address(moonStaker) != address(0)) {
            // Set the previous MoonStaker contract allowance to zero
            ERC20(address(moonStaker.VAULT())).safeApprove(
                address(moonStaker),
                0
            );
        }

        moonStaker = _moonStaker;

        // Set the new MoonStaker contract allowance to max, enabling it
        // to do vault deposits and withdrawals on our behalf
        ERC20(address(_moonStaker.VAULT())).safeApprove(
            address(_moonStaker),
            type(uint256).max
        );

        emit SetMoonStaker(msg.sender, _moonStaker);
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
    function stakeETH()
        external
        nonReentrant
        returns (uint256 balance, uint256 assets, uint256 shares)
    {
        (assets, shares) = moonStaker.stakeETH{
            value: (balance = address(this).balance)
        }();

        emit StakeETH(msg.sender, balance, assets, shares);
    }

    /**
     * @notice Initiate a MOON redemption
     * @param  amount    uint256  MOON amount
     * @param  duration  uint256  Seconds to wait before redeeming the underlying stETH
     */
    function initiateRedemptionMOON(
        uint256 amount,
        uint256 duration
    ) external nonReentrant returns (uint256 redemptionAmount) {
        if (amount == 0) revert InvalidAmount();

        // If the duration is higher than the maximum, set it to the maximum
        if (duration > MAX_REDEMPTION_DURATION)
            duration = MAX_REDEMPTION_DURATION;

        // Burn MOON from msg.sender - reverts if their balance is insufficient
        _burn(msg.sender, amount);

        // Calculate the fixed xMOON amount (i.e. half of the total)
        uint256 fixedAmount = amount / 2;

        // Calculate the redemption amount by factoring in the variable xMOON amount
        // which is based on the duration
        redemptionAmount =
            fixedAmount +
            (
                duration == MAX_REDEMPTION_DURATION
                    ? (amount - fixedAmount)
                    : (amount - fixedAmount).mulDivDown(
                        duration,
                        MAX_REDEMPTION_DURATION
                    )
            );

        // Update state and enable the sender to redeem stETH after the duration
        // Using add-assignment operator in case the user has multiple same-block redemptions
        redemptions[msg.sender][block.timestamp + duration] += redemptionAmount;

        emit InitiateRedemption(msg.sender, amount, duration);
    }

    /**
     * @notice Redeem underlying MOON assets (e.g. stETH)
     * @param  redemptionTimestamp  uint256  MOON amount
     */
    function redeemMOON(
        uint256 redemptionTimestamp
    ) external nonReentrant returns (uint256) {
        // Cannot redeem before the redemption timestamp has past
        if (redemptionTimestamp < block.timestamp) revert InvalidTimestamp();

        uint256 redemptionAmount = redemptions[msg.sender][redemptionTimestamp];

        if (redemptionAmount == 0) revert InvalidAmount();

        // Zero out the redemption amount prior to transferring stETH
        redemptions[msg.sender][redemptionTimestamp] = 0;

        // Attempt to return ETH to the user with the contract balance
        if (address(this).balance >= redemptionAmount) {
            payable(msg.sender).safeTransferETH(redemptionAmount);

            return redemptionAmount;
        }

        // If the ETH balance is insufficient to cover the redemption, stake it
        // Doing so prevents the unlikely "limbo" scenario where neither the
        // ETH balance nor vault can cover the redemption amount
        if (address(this).balance != 0)
            moonStaker.stakeETH{value: address(this).balance}();

        // Withdraw assets from the vault for msg.sender
        return moonStaker.unstakeETH(redemptionAmount, msg.sender);
    }
}
