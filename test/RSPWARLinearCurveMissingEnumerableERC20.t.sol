// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePoolWithAssetRecipient} from "test/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPWARLinearCurveMissingEnumerableERC20Test is RouterSinglePoolWithAssetRecipient, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
