// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/sudoswap/base/RouterMultiPool.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RMPExponentialCurveMissingEnumerableERC20Test is RouterMultiPool, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
