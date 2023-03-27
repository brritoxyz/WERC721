// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithRoyalties} from "test/sudoswap/base/RouterRobustSwapWithRoyalties.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSWRLinearCurveEnumerableERC20Test is RouterRobustSwapWithRoyalties, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
