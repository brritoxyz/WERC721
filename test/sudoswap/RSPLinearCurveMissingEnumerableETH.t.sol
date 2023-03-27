// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePool} from "test/sudoswap/base/RouterSinglePool.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RSPLinearCurveMissingEnumerableETHTest is RouterSinglePool, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
