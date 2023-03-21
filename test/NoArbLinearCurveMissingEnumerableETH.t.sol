// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract NoArbLinearCurveMissingEnumerableETHTest is NoArbBondingCurve, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
