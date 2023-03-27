// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithAssetRecipient} from "test/sudoswap/base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RSPWARLinearCurveMissingEnumerableERC20Test is RouterSinglePoolWithAssetRecipient, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
