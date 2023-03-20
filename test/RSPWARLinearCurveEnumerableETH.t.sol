// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePoolWithAssetRecipient} from "test/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RSPWARLinearCurveEnumerableETHTest is RouterSinglePoolWithAssetRecipient, UsingLinearCurve, UsingEnumerable, UsingETH {}
