// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePool} from "test/base/RouterSinglePool.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPLinearCurveEnumerableERC20Test is RouterSinglePool, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
