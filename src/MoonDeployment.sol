// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Moon} from "src/Moon.sol";
import {MoonBookFactory} from "src/MoonBookFactory.sol";

contract MoonDeployment {
    Moon public immutable moon;
    MoonBookFactory public immutable factory;

    constructor(address owner) {
        // Temporarily set owner to the deployer contract until configuration is complete
        moon = new Moon(address(this));

        factory = new MoonBookFactory(moon);

        // Enable factory to add MoonBook contracts as minters upon deployment
        moon.setFactory(address(factory));

        // Transfer token ownership to designated account
        moon.transferOwnership(owner);
    }
}
