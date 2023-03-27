// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithAssetRecipient} from "test/sudoswap/base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RRSWARXykCurveEnumerableETHTest is RouterRobustSwapWithAssetRecipient, UsingXykCurve, UsingEnumerable, UsingETH {}
