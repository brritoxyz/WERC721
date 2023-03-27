// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePool} from "test/sudoswap/base/RouterSinglePool.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RSPLinearCurveMissingEnumerableERC20Test is RouterSinglePool, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
