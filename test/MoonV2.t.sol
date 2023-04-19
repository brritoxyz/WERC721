// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Moon} from "src/MoonV2.sol";
import {MoonStaker} from "src/MoonStaker.sol";

contract MoonTest is Test {
    bytes private constant UNAUTHORIZED_ERROR = bytes("UNAUTHORIZED");

    Moon private immutable moon;
    MoonStaker private immutable moonStaker;
    address private immutable moonAddr;

    event SetMoonStaker(address indexed msgSender, MoonStaker moonStaker);
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

        moon.setMoonStaker(moonStaker);
    }

    function testCannotSetMoonStakerUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(UNAUTHORIZED_ERROR);

        moon.setMoonStaker(moonStaker);
    }

    function testCannotSetMoonStakerInvalidAddress() external {
        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.setMoonStaker(MoonStaker(address(0)));
    }

    function testSetMoonStaker() external {
        address msgSender = address(this);
        MoonStaker newMoonStaker = new MoonStaker(moonAddr);

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
