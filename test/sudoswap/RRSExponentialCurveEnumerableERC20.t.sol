// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwap} from "test/sudoswap/base/RouterRobustSwap.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSExponentialCurveEnumerableERC20Test is RouterRobustSwap, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}