// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwapWithAssetRecipient} from "test/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RRSWARXykCurveMissingEnumerableETHTest is RouterRobustSwapWithAssetRecipient, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
