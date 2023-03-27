// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/sudoswap/base/PairAndFactory.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract PAFLinearCurveEnumerableETHTest is PairAndFactory, UsingLinearCurve, UsingEnumerable, UsingETH {}
