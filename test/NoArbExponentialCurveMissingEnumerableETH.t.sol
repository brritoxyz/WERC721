// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract NoArbExponentialCurveMissingEnumerableETHTest is NoArbBondingCurve, UsingExponentialCurve, UsingMissingEnumerable, UsingETH {}
