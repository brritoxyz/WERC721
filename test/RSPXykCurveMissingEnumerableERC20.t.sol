// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePool} from "test/base/RouterSinglePool.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPXykCurveMissingEnumerableERC20Test is RouterSinglePool, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}