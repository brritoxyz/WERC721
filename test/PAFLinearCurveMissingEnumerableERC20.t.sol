// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/base/PairAndFactory.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract PAFLinearCurveMissingEnumerableERC20Test is PairAndFactory, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
