// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RMPExponentialCurveEnumerableETHTest is RouterMultiPool, UsingExponentialCurve, UsingEnumerable, UsingETH {}
