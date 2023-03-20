// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePool} from "test/base/RouterSinglePool.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPExponentialCurveMissingEnumerableERC20Test is RouterSinglePool, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
