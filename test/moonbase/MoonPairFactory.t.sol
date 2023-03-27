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

contract MoonPairFactoryTest is Test {
    // 0.30%
    uint256 internal constant DEFAULT_PROTOCOL_FEE = 0.003e18;

    // Unchanged SudoSwap contracts
    LinearCurve internal immutable linearCurve = new LinearCurve();
    PairFactory internal immutable factory;

    // Moonbase
    RouterWithRoyalties internal immutable moonRouter;
    Moon internal immutable moon;

    event SetMoon(Moon);

    constructor() {
        // Deploy PairFactory with template addresses and fee config
        factory = new PairFactory(
            new PairEnumerableETH(),
            new PairMissingEnumerableETH(),
            new PairEnumerableERC20(),
            new PairMissingEnumerableERC20(),
            payable(address(this)),
            DEFAULT_PROTOCOL_FEE
        );

        // Whitelist bonding curve
        factory.setBondingCurveAllowed(linearCurve, true);

        // Deploy MoonRouter
        moonRouter = new RouterWithRoyalties(factory);

        // Whitelist MoonRouter
        factory.setRouterAllowed(moonRouter, true);

        // Deploy Moon
        moon = new Moon(address(this));

        // Enable factory to add minters
        moon.setFactory(address(factory));
    }

    function testCannotSetMoonUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(bytes("UNAUTHORIZED"));

        factory.setMoon(moon);
    }

    function testCannotSetMoonInvalidAddress() external {
        Moon _moon = Moon(address(0));

        vm.expectRevert(PairFactory.InvalidAddress.selector);

        factory.setMoon(_moon);
    }

    function testCannotSetMoonAlreadySet() external {
        factory.setMoon(moon);

        vm.expectRevert(PairFactory.AlreadySet.selector);

        factory.setMoon(moon);
    }

    function testSetMoon() external {
        assertTrue(factory.moon() != moon);

        vm.expectEmit(false, false, false, true, address(factory));

        emit SetMoon(moon);

        factory.setMoon(moon);

        assertTrue(factory.moon() == moon);
    }
}
