// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithAssetRecipient} from "test/sudoswap/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RSPWARXykCurveMissingEnumerableETHTest is RouterSinglePoolWithAssetRecipient, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
