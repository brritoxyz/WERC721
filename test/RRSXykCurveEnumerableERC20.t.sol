// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwap} from "test/base/RouterRobustSwap.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSXykCurveEnumerableERC20Test is RouterRobustSwap, UsingXykCurve, UsingEnumerable, UsingERC20 {}