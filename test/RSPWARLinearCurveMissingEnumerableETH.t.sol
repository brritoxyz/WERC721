// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePoolWithAssetRecipient} from "test/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RSPWARLinearCurveMissingEnumerableETHTest is RouterSinglePoolWithAssetRecipient, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
