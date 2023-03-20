// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwap} from "test/base/RouterRobustSwap.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSXykCurveMissingEnumerableERC20Test is RouterRobustSwap, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}
