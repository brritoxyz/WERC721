// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithAssetRecipient} from "test/sudoswap/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RRSWARLinearCurveEnumerableERC20Test is RouterRobustSwapWithAssetRecipient, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
