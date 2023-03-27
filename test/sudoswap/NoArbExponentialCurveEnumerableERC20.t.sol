// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {NoArbBondingCurve} from "test/sudoswap/base/NoArbBondingCurve.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract NoArbExponentialCurveEnumerableERC20Test is NoArbBondingCurve, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
