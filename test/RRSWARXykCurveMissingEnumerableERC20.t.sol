// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwapWithAssetRecipient} from "test/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSWARXykCurveMissingEnumerableERC20Test is RouterRobustSwapWithAssetRecipient, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}
