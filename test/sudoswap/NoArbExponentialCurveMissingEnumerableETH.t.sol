// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {NoArbBondingCurve} from "test/sudoswap/base/NoArbBondingCurve.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract NoArbExponentialCurveMissingEnumerableETHTest is NoArbBondingCurve, UsingExponentialCurve, UsingMissingEnumerable, UsingETH {}
