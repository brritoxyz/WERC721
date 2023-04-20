// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Moon, IMoonStaker} from "src/MoonV2.sol";
import {MoonStaker} from "src/MoonStaker.sol";

interface ILido {
    function getSharesByPooledEth(uint256) external view returns (uint256);

    function getPooledEthByShares(uint256) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}

interface IUserModule {
    function balanceOf(address) external view returns (uint256);

    function previewDeposit(uint256) external view returns (uint256);

    function convertToAssets(uint256) external view returns (uint256);

    function getWithdrawFee(uint256) external view returns (uint256);
}

contract MoonTest is Test {
    using FixedPointMathLib for uint256;

    bytes private constant UNAUTHORIZED_ERROR = bytes("UNAUTHORIZED");
    uint256 private constant FUZZ_ETH_AMOUNT = 0.00001 ether;

    // Due to Lido's share-balance accounting, there may be a small discrepancy
    // between expected balances and actual balances. This is the maximum amount
    uint256 private constant LIDO_ERROR_MARGIN = 10;

    Moon private immutable moon;
    MoonStaker private immutable moonStaker;
    address private immutable moonAddr;
    ILido private immutable lido;
    IUserModule private immutable vault;
    uint256 private immutable maxRedemptionDuration;

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

    constructor() {
        moon = new Moon();

        // To avoid redundant casting
        moonAddr = address(moon);

        moonStaker = new MoonStaker(moonAddr);
        lido = ILido(address(moonStaker.LIDO()));
        vault = IUserModule(address(moonStaker.VAULT()));

        moon.setMoonStaker(IMoonStaker(address(new MoonStaker(moonAddr))));

        maxRedemptionDuration = moon.MAX_REDEMPTION_DURATION();
    }

    function _toStEth(uint256 ethAmount) private view returns (uint256) {
        return lido.getPooledEthByShares(lido.getSharesByPooledEth(ethAmount));
    }

    function _previewDeposit(uint256 assets) private view returns (uint256) {
        return vault.previewDeposit(assets);
    }

    function _convertToAssets(uint256 shares) private view returns (uint256) {
        return vault.convertToAssets(shares);
    }

    function _calculateRedeemedAssets(
        uint256 redemptionAmount,
        uint256 totalSupply,
        uint256 outstandingRedemptions
    ) private view returns (uint256) {
        uint256 assets = moonStaker.totalAssets().mulDivDown(
            redemptionAmount,
            totalSupply + outstandingRedemptions
        );

        // Factor in the 0.05% vault fee
        return assets - vault.getWithdrawFee(assets);
    }

    function testCannotSetMoonStakerUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(UNAUTHORIZED_ERROR);

        moon.setMoonStaker(IMoonStaker(address(moonStaker)));
    }

    function testCannotSetMoonStakerInvalidAddress() external {
        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.setMoonStaker(IMoonStaker(address(0)));
    }

    function testSetMoonStaker() external {
        address msgSender = address(this);
        IMoonStaker newMoonStaker = IMoonStaker(
            address(new MoonStaker(moonAddr))
        );

        assertEq(msgSender, moon.owner());
        assertFalse(address(newMoonStaker) == address(moon.moonStaker()));

        vm.expectEmit(true, false, false, true, moonAddr);

        emit SetMoonStaker(msgSender, newMoonStaker);

        moon.setMoonStaker(newMoonStaker);

        assertEq(address(newMoonStaker), address(moon.moonStaker()));
    }

    function testCannotDepositETHInvalidAmount() external {
        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.depositETH{value: 0}();
    }

    function testDepositETH(
        address msgSender,
        uint32 amount,
        uint8 iterations
    ) external {
        vm.assume(msgSender != address(0));
        vm.assume(amount != 0);
        vm.assume(iterations != 0);
        vm.assume(iterations < 20);

        uint256 ethBalance;
        uint256 moonBalance;

        for (uint256 i; i < iterations; ) {
            uint256 ethAmount = uint256(amount) * FUZZ_ETH_AMOUNT;

            ethBalance += ethAmount;
            moonBalance += ethAmount;

            vm.deal(msgSender, ethAmount);
            vm.prank(msgSender);
            vm.expectEmit(true, false, false, true, moonAddr);

            emit DepositETH(msgSender, ethAmount);

            moon.depositETH{value: ethAmount}();

            assertEq(moonBalance, ethBalance);
            assertEq(moonBalance, moon.balanceOf(msgSender));
            assertEq(ethBalance, moonAddr.balance);

            unchecked {
                ++i;
            }
        }
    }

    function testStakeETH(
        address msgSender,
        uint8 amount,
        uint8 iterations
    ) external {
        vm.assume(msgSender != address(0));
        vm.assume(amount != 0);
        vm.assume(iterations != 0);
        vm.assume(iterations < 20);

        // NOTE: This is the minimum amount of Instadapp shares that the Moon contract should have
        // Difficult to get the precise amount since the Lido stETH calculation occasionally varies by 1
        uint256 minimumSharesBalance;

        for (uint256 i; i < iterations; ) {
            uint256 ethAmount = uint256(amount) * FUZZ_ETH_AMOUNT;

            vm.deal(msgSender, ethAmount);

            uint256 expectedAssets = _toStEth(ethAmount);
            uint256 expectedShares = _previewDeposit(expectedAssets);

            minimumSharesBalance += expectedShares;

            moon.depositETH{value: ethAmount}();

            vm.prank(msgSender);

            // Not going to compare the emitted event member values since the values may occasionally be off by 1
            vm.expectEmit(true, false, false, false, moonAddr);

            emit StakeETH(msgSender, ethAmount, expectedAssets, expectedShares);

            (uint256 balance, uint256 assets, uint256 shares) = moon.stakeETH();

            assertEq(ethAmount, balance);
            assertLe(expectedAssets, assets);
            assertLe(expectedShares, shares);
            assertLe(minimumSharesBalance, vault.balanceOf(moonAddr));

            unchecked {
                ++i;
            }
        }
    }

    function testCannotInitiateRedemptionMOONInvalidAmount() external {
        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.initiateRedemptionMOON(0, 0);
    }

    function testInitiateRedemptionMOON(
        uint32 _amount,
        uint8 redemptionDenominator,
        uint24 duration
    ) external {
        vm.assume(_amount != 0);
        vm.assume(redemptionDenominator != 0);

        uint256 depositAmount = uint256(_amount) * FUZZ_ETH_AMOUNT;

        if (duration > maxRedemptionDuration) {
            duration = uint24(maxRedemptionDuration);
        }

        // Deposit and stake ETH to provision test assets
        moon.depositETH{value: depositAmount}();
        moon.stakeETH();

        uint256 amount = depositAmount / redemptionDenominator;
        uint256 balanceBefore = moon.balanceOf(address(this));
        uint256 supplyBefore = moon.totalSupply();
        uint256 outstandingBefore = moon.outstandingRedemptions();
        uint256 redemptionTimestamp = block.timestamp + duration;

        vm.expectEmit(true, false, false, true, moonAddr);

        emit InitiateRedemption(address(this), amount, duration);

        uint256 redemptionAmount = moon.initiateRedemptionMOON(
            amount,
            duration
        );

        assertEq(
            redemptionAmount,
            moon.redemptions(address(this), redemptionTimestamp)
        );
        assertEq(balanceBefore - amount, moon.balanceOf(address(this)));
        assertEq(supplyBefore - amount, moon.totalSupply());
        assertEq(
            outstandingBefore + redemptionAmount,
            moon.outstandingRedemptions()
        );
    }

    function testCannotRedeemMOONInvalidTimestamp() external {
        vm.expectRevert(Moon.InvalidTimestamp.selector);

        // Reverts on any timestamp less than the current
        moon.redeemMOON(block.timestamp - 1);
    }

    function testRedeemMOON(
        uint32 _amount,
        uint8 redemptionDenominator,
        uint24 duration
    ) external {
        vm.assume(_amount != 0);
        vm.assume(redemptionDenominator != 0);

        if (duration > maxRedemptionDuration) {
            duration = uint24(maxRedemptionDuration);
        }

        uint256 depositAmount = uint256(_amount) * FUZZ_ETH_AMOUNT;
        uint256 amount = depositAmount / redemptionDenominator;
        uint256 redemptionTimestamp = block.timestamp + duration;

        moon.depositETH{value: depositAmount}();
        moon.stakeETH();

        uint256 redemptionAmount = moon.initiateRedemptionMOON(
            amount,
            duration
        );
        uint256 outstandingBefore = moon.outstandingRedemptions();
        uint256 sharesBefore = vault.balanceOf(moonAddr);

        // Get the proportion asset withdrawal amount and factor in 0.05% vault fee
        uint256 expectedAssets = _calculateRedeemedAssets(
            redemptionAmount,
            moon.totalSupply(),
            outstandingBefore
        );

        vm.warp(redemptionTimestamp);

        (uint256 assets, uint256 shares) = moon.redeemMOON(redemptionTimestamp);

        assertEq(
            outstandingBefore - redemptionAmount,
            moon.outstandingRedemptions()
        );
        assertLe(
            expectedAssets - LIDO_ERROR_MARGIN,
            lido.balanceOf(address(this))
        );
        assertEq(expectedAssets, assets - vault.getWithdrawFee(assets));
        assertEq(sharesBefore - shares, vault.balanceOf(moonAddr));
    }
}
