// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract NoArbLinearCurveMissingEnumerableERC20Test is NoArbBondingCurve, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
