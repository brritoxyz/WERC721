// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePool} from "test/sudoswap/base/RouterSinglePool.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RSPXykCurveMissingEnumerableERC20Test is RouterSinglePool, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}
