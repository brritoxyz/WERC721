// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {NoArbBondingCurve} from "test/sudoswap/base/NoArbBondingCurve.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract NoArbXykCurveEnumerableETHTest is NoArbBondingCurve, UsingXykCurve, UsingEnumerable, UsingETH {}
