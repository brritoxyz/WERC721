// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePool} from "test/base/RouterSinglePool.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RSPLinearCurveEnumerableETHTest is RouterSinglePool, UsingLinearCurve, UsingEnumerable, UsingETH {}
