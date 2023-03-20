// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwapWithRoyalties} from "test/base/RouterRobustSwapWithRoyalties.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSWRLinearCurveMissingEnumerableERC20Test is RouterRobustSwapWithRoyalties, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
