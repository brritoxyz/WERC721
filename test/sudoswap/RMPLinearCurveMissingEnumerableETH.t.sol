// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/sudoswap/base/RouterMultiPool.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RMPLinearCurveMissingEnumerableETHTest is RouterMultiPool, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
