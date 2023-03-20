// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract NoArbXykCurveEnumerableETHTest is NoArbBondingCurve, UsingXykCurve, UsingEnumerable, UsingETH {}
