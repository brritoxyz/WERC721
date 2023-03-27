// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithAssetRecipient} from "test/sudoswap/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RSPWARExponentialCurveEnumerableETHTest is RouterSinglePoolWithAssetRecipient, UsingExponentialCurve, UsingEnumerable, UsingETH {}
