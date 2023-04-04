// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {MoonDeployment} from "src/MoonDeployment.sol";
import {Moon} from "src/Moon.sol";
import {MoonBookFactory} from "src/MoonBookFactory.sol";

contract Moonbase is Test {
    Moon internal immutable moon;
    MoonBookFactory internal immutable factory;

    constructor() {
        MoonDeployment deployment = new MoonDeployment(address(this));
        moon = deployment.moon();
        factory = deployment.factory();

        assertEq(address(this), moon.owner());
        assertEq(address(factory), moon.factory());
        assertEq(address(moon), address(factory.moon()));
    }
}
