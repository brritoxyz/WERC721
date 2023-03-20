// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwapWithAssetRecipient} from "test/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSWARExponentialCurveEnumerableERC20Test is RouterRobustSwapWithAssetRecipient, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
