// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPXykCurveEnumerableERC20Test is RouterMultiPool, UsingXykCurve, UsingEnumerable, UsingERC20 {}
