// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPXykCurveMissingEnumerableERC20Test is RouterMultiPool, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}
