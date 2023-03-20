// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPExponentialCurveMissingEnumerableERC20Test is RouterMultiPool, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
