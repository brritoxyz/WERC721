// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract NoArbXykCurveMissingEnumerableERC20Test is NoArbBondingCurve, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}
