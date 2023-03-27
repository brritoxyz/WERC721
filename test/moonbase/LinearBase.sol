// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {LinearCurve} from "src/bonding-curves/LinearCurve.sol";
import {PairMissingEnumerableETH} from "sudoswap/PairMissingEnumerableETH.sol";
import {PairEnumerableERC20} from "sudoswap/PairEnumerableERC20.sol";
import {PairMissingEnumerableERC20} from "sudoswap/PairMissingEnumerableERC20.sol";
import {PairEnumerableETH} from "src/MoonPairEnumerableETH.sol";
import {PairFactory} from "src/MoonPairFactory.sol";
import {RouterWithRoyalties} from "src/MoonRouter.sol";
import {MoonToken} from "src/MoonToken.sol";

contract LinearBase is Test {
    // 0.30%
    uint256 internal constant DEFAULT_PROTOCOL_FEE = 0.003e18;

    // Unchanged SudoSwap contracts
    LinearCurve internal immutable linearCurve = new LinearCurve();
    PairFactory internal immutable factory;

    // Moonbase
    RouterWithRoyalties internal immutable moonRouter;
    MoonToken internal immutable moon;

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

        // Deploy MoonToken
        moon = new MoonToken(address(this));

        // Enable factory to add minters
        moon.setFactory(address(factory));
    }
}
