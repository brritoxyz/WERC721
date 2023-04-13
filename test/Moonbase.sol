// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {MoonDeployment} from "src/MoonDeployment.sol";
import {Moon} from "src/Moon.sol";
import {MoonBookFactory} from "src/MoonBookFactory.sol";

contract Moonbase is Test {
    // Commonly-used constants
    bytes internal constant NOT_OWNER_ERROR = bytes("UNAUTHORIZED");

    Moon internal immutable moon;
    MoonBookFactory internal immutable factory;

    address[3] internal testAccounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];
    address[3] internal testBuyers = [
        address(1e18),
        address(2e18),
        address(3e18)
    ];
    address[3] internal testSellers = [
        address(4e18),
        address(5e18),
        address(6e18)
    ];

    constructor() {
        MoonDeployment deployment = new MoonDeployment(address(this));
        moon = deployment.moon();
        factory = deployment.factory();

        assertEq(address(this), moon.owner());
        assertEq(address(factory), moon.factory());
        assertEq(address(moon), address(factory.moon()));
    }
}
