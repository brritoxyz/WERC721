// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithAssetRecipient} from "test/sudoswap/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSWARLinearCurveMissingEnumerableERC20Test is RouterRobustSwapWithAssetRecipient, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
