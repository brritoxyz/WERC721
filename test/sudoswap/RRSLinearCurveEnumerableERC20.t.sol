// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwap} from "test/sudoswap/base/RouterRobustSwap.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSLinearCurveEnumerableERC20Test is RouterRobustSwap, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
