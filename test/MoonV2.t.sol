// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {Moon} from "src/MoonV2.sol";

interface ILido {
    function getSharesByPooledEth(uint256) external view returns (uint256);

    function getPooledEthByShares(uint256) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}

contract MoonTest is Test {
    Moon private immutable moon;
    address private immutable moonAddr;
    ILido private immutable lido;

    event DepositETH(address indexed msgSender, uint256 msgValue);

    constructor() {
        moon = new Moon(address(this));

        // To avoid redundant casting
        moonAddr = address(moon);

        // Lido with a different contract interface for testing only
        lido = ILido(address(moon.LIDO()));
    }

    function testCannotDepositETHInvalidAmount() external {
        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.depositETH{value: 0}();
    }

    function testDepositETH(address msgSender, uint8 amount) external {
        vm.assume(msgSender != address(0));
        vm.assume(amount != 0);

        uint256 ethAmount = uint256(amount) * 1 ether;

        vm.deal(msgSender, ethAmount);
        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(moon));

        emit DepositETH(msgSender, ethAmount);

        moon.depositETH{value: ethAmount}();

        // Calculate the amount of stETH received from the deposited ETH
        uint256 poolEthByShares = lido.getPooledEthByShares(
            lido.getSharesByPooledEth(ethAmount)
        );

        assertEq(poolEthByShares, lido.balanceOf(address(moon)));
        assertEq(ethAmount, moon.balanceOf(msgSender));
    }
}
