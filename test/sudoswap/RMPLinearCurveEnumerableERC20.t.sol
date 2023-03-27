// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/sudoswap/base/RouterMultiPool.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RMPLinearCurveEnumerableERC20Test is RouterMultiPool, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
