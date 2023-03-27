// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwap} from "test/sudoswap/base/RouterRobustSwap.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSLinearCurveMissingEnumerableERC20Test is RouterRobustSwap, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
