// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Moon} from "src/MoonV2.sol";
import {MoonStaker} from "src/MoonStaker.sol";

contract MoonTest is Test {
    Moon private immutable moon;
    MoonStaker private immutable moonStaker;
    address private immutable moonAddr;

    event StakeETH(address indexed msgSender, uint256 assets, uint256 shares);
    event DepositETH(address indexed msgSender, uint256 msgValue);

    constructor() {
        moon = new Moon();

        moonStaker = new MoonStaker(address(moon));

        // To avoid redundant casting
        moonAddr = address(moon);

        moon.setMoonStaker(moonStaker);
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
        vm.expectEmit(true, false, false, true, moonAddr);

        emit DepositETH(msgSender, ethAmount);

        moon.depositETH{value: ethAmount}();

        assertEq(ethAmount, moonAddr.balance);
        assertEq(ethAmount, moon.balanceOf(msgSender));
    }
}
