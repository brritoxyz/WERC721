// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

interface IMoonStaker {
    function stakeETH() external payable returns (uint256, uint256);
}

contract Moon is Owned, ERC20("Redeemable Token", "MOON", 18), ReentrancyGuard {
    using FixedPointMathLib for uint256;

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
        uint256 duration,
        address indexed recipient
    );

    error InvalidAddress();
    error InvalidAmount();

    constructor() Owned(msg.sender) {}

    /**
     * @notice Set MoonStaker contract
     * @param  _moonStaker  MoonStaker  MoonStaker contract
     */
    function setMoonStaker(IMoonStaker _moonStaker) external onlyOwner {
        if (address(_moonStaker) == address(0)) revert InvalidAddress();

        moonStaker = _moonStaker;

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
     * @return balance  uint256  Contract ETH balance that is staked
     */
    function stakeETH() external nonReentrant returns (uint256 balance) {
        (uint256 assets, uint256 shares) = moonStaker.stakeETH{
            value: (balance = address(this).balance)
        }();

        emit StakeETH(msg.sender, balance, assets, shares);
    }

    /**
     * @notice Initiate a MOON redemption
     * @param  amount     uint256  MOON amount
     * @param  duration   uint256  Seconds to wait before redeeming the underlying ETH
     * @param  recipient  address  Account that can redeem and receive the ETH
     */
    function initiateRedemptionMOON(
        uint256 amount,
        uint256 duration,
        address recipient
    ) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidAddress();

        // If the duration is higher than the maximum, set it to the maximum
        if (duration > MAX_REDEMPTION_DURATION)
            duration = MAX_REDEMPTION_DURATION;

        // Burn MOON from msg.sender - reverts if their balance is insufficient
        _burn(msg.sender, amount);

        // Calculate the fixed xMOON amount (i.e. half of the total)
        uint256 fixedAmount = amount / 2;

        // Calculate the variable xMOON amount (based on the redemption duration)
        // Update state and enable the recipient to redeem ETH after the duration
        redemptions[recipient][block.timestamp + duration] +=
            fixedAmount +
            (
                duration == MAX_REDEMPTION_DURATION
                    ? (amount - fixedAmount)
                    : (amount - fixedAmount).mulDivDown(
                        duration,
                        MAX_REDEMPTION_DURATION
                    )
            );

        emit InitiateRedemption(msg.sender, amount, duration, recipient);
    }
}
