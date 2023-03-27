// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {LinearCurve} from "src/bonding-curves/LinearCurve.sol";
import {PairMissingEnumerableETH} from "src/MoonPairMissingEnumerableETH.sol";
import {PairEnumerableERC20} from "sudoswap/PairEnumerableERC20.sol";
import {PairMissingEnumerableERC20} from "sudoswap/PairMissingEnumerableERC20.sol";
import {PairEnumerableETH} from "src/MoonPairEnumerableETH.sol";
import {PairFactory} from "src/MoonPairFactory.sol";
import {RouterWithRoyalties} from "src/MoonRouter.sol";
import {Moon} from "src/Moon.sol";

contract MoonTest is Test {
    address private immutable testFactory = address(this);

    // Moonbase
    Moon private immutable moon;

    address[3] private testAccounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    event SetFactory(address);
    event AddMinter(address);
    event IncreaseMintable(
        address indexed buyer,
        address indexed pair,
        uint256 buyerAmount,
        uint256 pairAmount
    );

    constructor() {
        // Deploy Moon
        moon = new Moon(address(this));

        // Set to this contract's address for testing purposes
        moon.setFactory(testFactory);
    }

    /*///////////////////////////////////////////////////////////////
                            setFactory
    //////////////////////////////////////////////////////////////*/

    function testCannotSetFactoryUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(bytes("UNAUTHORIZED"));

        moon.setFactory(testFactory);
    }

    function testCannotSetFactoryInvalidAddress() external {
        vm.expectRevert(PairFactory.InvalidAddress.selector);

        moon.setFactory(address(0));
    }

    function testSetFactoryFuzz(address _factory) external {
        vm.assume(_factory != address(0));

        assertTrue(_factory != moon.factory());

        vm.expectEmit(false, false, false, true, address(moon));

        emit SetFactory(_factory);

        moon.setFactory(_factory);

        assertTrue(_factory == moon.factory());
    }

    /*///////////////////////////////////////////////////////////////
                                addMinter
    //////////////////////////////////////////////////////////////*/

    function testCannotAddMinterUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(Moon.Unauthorized.selector);

        moon.addMinter(address(this));
    }

    function testCannotAddMinterInvalidAddress() external {
        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.addMinter(address(0));
    }

    function testAddMinter(address _minter) external {
        assertFalse(moon.minters(_minter));

        vm.expectEmit(false, false, false, true, address(moon));

        emit AddMinter(_minter);

        moon.addMinter(_minter);

        assertTrue(moon.minters(_minter));
    }

    /*///////////////////////////////////////////////////////////////
                            increaseMintable
    //////////////////////////////////////////////////////////////*/

    function testCannotIncreaseMintableUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(Moon.Unauthorized.selector);

        moon.increaseMintable(address(this), 1, 1);
    }

    function testCannotIncreaseMintableInvalidAddress() external {
        moon.addMinter(address(this));

        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.increaseMintable(address(0), 1, 1);
    }

    function testCannotIncreaseMintableInvalidAmount() external {
        moon.addMinter(address(this));

        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.increaseMintable(address(this), 0, 1);
    }

    function testIncreaseMintableFuzz(
        uint256 buyerAmount,
        uint256 pairAmount
    ) external {
        // buyerAmount is never 0, but pairAmount may be 0
        vm.assume(buyerAmount != 0);

        // Set to self for testing purposes - would normally be pair contract
        address msgSender = address(this);

        address buyer = testAccounts[0];

        moon.addMinter(msgSender);

        assertTrue(moon.minters(msgSender));
        assertEq(0, moon.mintable(buyer));
        assertEq(0, moon.mintable(msgSender));

        vm.expectEmit(true, true, false, true, address(moon));

        emit IncreaseMintable(buyer, msgSender, buyerAmount, pairAmount);

        moon.increaseMintable(buyer, buyerAmount, pairAmount);

        assertEq(buyerAmount, moon.mintable(buyer));
        assertEq(pairAmount, moon.mintable(msgSender));
    }
}
