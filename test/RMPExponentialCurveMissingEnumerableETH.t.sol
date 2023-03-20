// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RMPExponentialCurveMissingEnumerableETHTest is RouterMultiPool, UsingExponentialCurve, UsingMissingEnumerable, UsingETH {}
