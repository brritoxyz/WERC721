// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {PairAndFactory} from "test/base/PairAndFactory.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract PAFXykCurveEnumerableERC20Test is PairAndFactory, UsingXykCurve, UsingEnumerable, UsingERC20 {}
