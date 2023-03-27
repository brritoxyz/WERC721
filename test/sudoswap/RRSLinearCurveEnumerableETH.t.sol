// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwap} from "test/sudoswap/base/RouterRobustSwap.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RRSLinearCurveEnumerableETHTest is RouterRobustSwap, UsingLinearCurve, UsingEnumerable, UsingETH {}
