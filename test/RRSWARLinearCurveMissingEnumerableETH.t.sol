// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwapWithAssetRecipient} from "test/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RRSWARLinearCurveMissingEnumerableETHTest is RouterRobustSwapWithAssetRecipient, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
