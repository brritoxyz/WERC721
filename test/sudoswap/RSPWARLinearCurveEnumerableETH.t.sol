// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithAssetRecipient} from "test/sudoswap/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RSPWARLinearCurveEnumerableETHTest is RouterSinglePoolWithAssetRecipient, UsingLinearCurve, UsingEnumerable, UsingETH {}
