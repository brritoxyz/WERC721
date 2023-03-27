// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/sudoswap/base/RouterMultiPool.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RMPExponentialCurveEnumerableETHTest is RouterMultiPool, UsingExponentialCurve, UsingEnumerable, UsingETH {}
