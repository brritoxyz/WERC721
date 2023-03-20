// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwapWithAssetRecipient} from "test/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RRSWARLinearCurveMissingEnumerableERC20Test is RouterRobustSwapWithAssetRecipient, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
