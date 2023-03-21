// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPLinearCurveMissingEnumerableERC20Test is RouterMultiPool, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
