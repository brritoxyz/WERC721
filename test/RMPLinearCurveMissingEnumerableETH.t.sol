// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RMPLinearCurveMissingEnumerableETHTest is RouterMultiPool, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
