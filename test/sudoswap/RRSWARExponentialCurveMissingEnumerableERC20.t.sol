// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithAssetRecipient} from "test/sudoswap/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSWARExponentialCurveMissingEnumerableERC20Test is RouterRobustSwapWithAssetRecipient, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}