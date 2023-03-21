// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/base/PairAndFactory.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract PAFXykCurveMissingEnumerableERC20Test is PairAndFactory, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}
