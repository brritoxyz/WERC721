// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePool} from "test/base/RouterSinglePool.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPLinearCurveMissingEnumerableERC20Test is RouterSinglePool, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
