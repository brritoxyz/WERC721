// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {NoArbBondingCurve} from "test/sudoswap/base/NoArbBondingCurve.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract NoArbExponentialCurveMissingEnumerableERC20Test is NoArbBondingCurve, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
