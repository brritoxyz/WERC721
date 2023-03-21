// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithRoyalties} from "test/base/RouterRobustSwapWithRoyalties.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSWRXykCurveEnumerableERC20Test is RouterRobustSwapWithRoyalties, UsingXykCurve, UsingEnumerable, UsingERC20 {}
