// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract NoArbExponentialCurveEnumerableERC20Test is NoArbBondingCurve, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
