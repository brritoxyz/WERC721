// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithAssetRecipient} from "test/sudoswap/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RSPWARXykCurveMissingEnumerableERC20Test is RouterSinglePoolWithAssetRecipient, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}
