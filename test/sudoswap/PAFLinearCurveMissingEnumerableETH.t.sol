// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/sudoswap/base/PairAndFactory.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract PAFLinearCurveMissingEnumerableETHTest is PairAndFactory, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
