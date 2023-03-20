// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwap} from "test/base/RouterRobustSwap.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSLinearCurveEnumerableERC20Test is RouterRobustSwap, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
