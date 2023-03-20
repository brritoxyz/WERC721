// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwapWithRoyalties} from "test/base/RouterRobustSwapWithRoyalties.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RRSWRLinearCurveEnumerableETHTest is RouterRobustSwapWithRoyalties, UsingLinearCurve, UsingEnumerable, UsingETH {}
