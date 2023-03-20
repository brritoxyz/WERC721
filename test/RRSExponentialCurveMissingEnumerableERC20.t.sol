// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwap} from "test/base/RouterRobustSwap.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSExponentialCurveMissingEnumerableERC20Test is RouterRobustSwap, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
