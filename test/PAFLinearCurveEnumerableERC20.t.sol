// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {PairAndFactory} from "test/base/PairAndFactory.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract PAFLinearCurveEnumerableERC20Test is PairAndFactory, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
