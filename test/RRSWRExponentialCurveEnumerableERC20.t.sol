// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithRoyalties} from "test/base/RouterRobustSwapWithRoyalties.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSWRExponentialCurveEnumerableERC20Test is RouterRobustSwapWithRoyalties, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
