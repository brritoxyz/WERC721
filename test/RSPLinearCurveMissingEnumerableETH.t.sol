// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePool} from "test/base/RouterSinglePool.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RSPLinearCurveMissingEnumerableETHTest is RouterSinglePool, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
