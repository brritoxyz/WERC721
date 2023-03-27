// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithRoyalties} from "test/sudoswap/base/RouterRobustSwapWithRoyalties.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSWRExponentialCurveEnumerableERC20Test is RouterRobustSwapWithRoyalties, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
