// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithAssetRecipient} from "test/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPWARXykCurveMissingEnumerableERC20Test is RouterSinglePoolWithAssetRecipient, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}