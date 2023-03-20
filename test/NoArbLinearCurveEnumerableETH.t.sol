// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract NoArbLinearCurveEnumerableETHTest is NoArbBondingCurve, UsingLinearCurve, UsingEnumerable, UsingETH {}
