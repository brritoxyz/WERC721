// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPLinearCurveEnumerableERC20Test is RouterMultiPool, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
