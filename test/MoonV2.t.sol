// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
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
}

contract MoonTest is Test {
    bytes private constant UNAUTHORIZED_ERROR = bytes("UNAUTHORIZED");
    uint256 private constant FUZZ_ETH_AMOUNT = 0.00001 ether;

    Moon private immutable moon;
    MoonStaker private immutable moonStaker;
    address private immutable moonAddr;
    ILido private immutable lido;
    IUserModule private immutable instadapp;

    event SetMoonStaker(address indexed msgSender, IMoonStaker moonStaker);
    event StakeETH(
        address indexed msgSender,
        uint256 balance,
        uint256 assets,
        uint256 shares
    );
    event DepositETH(address indexed msgSender, uint256 msgValue);

    constructor() {
        moon = new Moon();

        // To avoid redundant casting
        moonAddr = address(moon);

        moonStaker = new MoonStaker(moonAddr);
        lido = ILido(address(moonStaker.LIDO()));
        instadapp = IUserModule(address(moonStaker.VAULT()));

        moon.setMoonStaker(IMoonStaker(address(new MoonStaker(moonAddr))));
    }

    function _toStEth(uint256 ethAmount) private view returns (uint256) {
        return lido.getPooledEthByShares(lido.getSharesByPooledEth(ethAmount));
    }

    function _previewDeposit(uint256 assets) private view returns (uint256) {
        return instadapp.previewDeposit(assets);
    }

    function _convertToAssets(uint256 shares) private view returns (uint256) {
        return instadapp.convertToAssets(shares);
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
        uint8 amount,
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

            uint256 balance = moon.stakeETH();

            assertEq(ethAmount, balance);
            assertLe(minimumSharesBalance, instadapp.balanceOf(moonAddr));

            unchecked {
                ++i;
            }
        }
    }
}
