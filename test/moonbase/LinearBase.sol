// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {LinearCurve} from "src/bonding-curves/LinearCurve.sol";
import {PairEnumerableETH} from "sudoswap/PairEnumerableETH.sol";
import {PairMissingEnumerableETH} from "sudoswap/PairMissingEnumerableETH.sol";
import {PairEnumerableERC20} from "sudoswap/PairEnumerableERC20.sol";
import {PairMissingEnumerableERC20} from "sudoswap/PairMissingEnumerableERC20.sol";
import {PairFactory} from "sudoswap/PairFactory.sol";
import {RouterWithRoyalties} from "src/MoonRouter.sol";

contract LinearBase is Test {
    // 0.40%
    uint256 private constant PROTOCOL_FEE_MULTIPLIER = 0.004e18;

    // Unchanged SudoSwap contracts
    LinearCurve private immutable linearCurve = new LinearCurve();
    PairFactory private immutable pairFactory;
    PairEnumerableETH private immutable pairEnumerableETH;
    PairMissingEnumerableETH private immutable pairMissingEnumerableETH;
    PairEnumerableERC20 private immutable pairEnumerableERC20;
    PairMissingEnumerableERC20 private immutable pairMissingEnumerableERC20;

   // Moonbase
    RouterWithRoyalties private immutable moonRouter;

    constructor() {
        pairEnumerableETH = new PairEnumerableETH();
        pairMissingEnumerableETH = new PairMissingEnumerableETH();
        pairEnumerableERC20 = new PairEnumerableERC20();
        pairMissingEnumerableERC20 = new PairMissingEnumerableERC20();

        // Deploy PairFactory with template addresses and fee config
        pairFactory = new PairFactory(
            pairEnumerableETH,
            pairMissingEnumerableETH,
            pairEnumerableERC20,
            pairMissingEnumerableERC20,
            payable(address(this)),
            PROTOCOL_FEE_MULTIPLIER
        );

        // Whitelist bonding curve
        pairFactory.setBondingCurveAllowed(linearCurve, true);

        // Deploy MoonRouter
        moonRouter = new RouterWithRoyalties(pairFactory);

        // Whitelist MoonRouter
        pairFactory.setRouterAllowed(moonRouter, true);
    }
}
