// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithAssetRecipient} from "test/sudoswap/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSWARExponentialCurveEnumerableERC20Test is RouterRobustSwapWithAssetRecipient, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
