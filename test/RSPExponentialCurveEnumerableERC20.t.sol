// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePool} from "test/base/RouterSinglePool.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPExponentialCurveEnumerableERC20Test is RouterSinglePool, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
