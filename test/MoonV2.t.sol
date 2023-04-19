// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Moon} from "src/MoonV2.sol";

interface ILido {
    function getSharesByPooledEth(uint256) external view returns (uint256);

    function getPooledEthByShares(uint256) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}

interface IUserModule {
    function balanceOf(address) external view returns (uint256);

    function convertToShares(uint256) external view returns (uint256);

    function convertToAssets(uint256) external view returns (uint256);
}

contract MoonTest is Test {
    Moon private immutable moon;
    address private immutable moonAddr;
    ILido private immutable lido;
    IUserModule private immutable instadapp;

    event DepositETH(
        address indexed msgSender,
        uint256 msgValue,
        uint256 shares
    );

    constructor() {
        moon = new Moon(address(this));

        // To avoid redundant casting
        moonAddr = address(moon);

        // Lido with a different contract interface for testing only
        lido = ILido(address(moon.LIDO()));

        // Instadapp with an ERC20 interface
        instadapp = IUserModule(address(moon.INSTADAPP()));
    }

    function _toStEth(uint256 ethAmount) private view returns (uint256) {
        return lido.getPooledEthByShares(lido.getSharesByPooledEth(ethAmount));
    }

    function _convertToShares(
        uint256 ethAmount
    ) private view returns (uint256) {
        return instadapp.convertToShares(_toStEth(ethAmount));
    }

    function _convertToAssets(uint256 shares) private view returns (uint256) {
        return instadapp.convertToAssets(shares);
    }

    function testCannotDepositETHInvalidAmount() external {
        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.depositETH{value: 0}();
    }

    function testDepositETH(address msgSender, uint8 amount) external {
        vm.assume(msgSender != address(0));
        vm.assume(amount != 0);

        uint256 ethAmount = uint256(amount) * 1 ether;
        uint256 expectedShares = _convertToShares(ethAmount);

        vm.deal(msgSender, ethAmount);
        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, moonAddr);

        emit DepositETH(msgSender, ethAmount, expectedShares);

        uint256 shares = moon.depositETH{value: ethAmount}();
        uint256 assets = _convertToAssets(expectedShares);

        assertEq(expectedShares, instadapp.balanceOf(moonAddr));
        assertEq(expectedShares, moon.balanceOf(msgSender));
        assertEq(expectedShares, shares);

        // We deduct 1 from the stETH amount (Instadapp does this to account for rounding)
        assertEq(_toStEth(ethAmount) - 1, assets);
    }
}
