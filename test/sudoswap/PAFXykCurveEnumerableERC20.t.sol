// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/sudoswap/base/PairAndFactory.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract PAFXykCurveEnumerableERC20Test is PairAndFactory, UsingXykCurve, UsingEnumerable, UsingERC20 {}
