// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwap} from "test/base/RouterRobustSwap.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSExponentialCurveEnumerableERC20Test is RouterRobustSwap, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
