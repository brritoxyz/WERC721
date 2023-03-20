// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract NoArbXykCurveMissingEnumerableETHTest is NoArbBondingCurve, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
