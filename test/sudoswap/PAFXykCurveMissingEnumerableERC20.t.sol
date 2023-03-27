// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/sudoswap/base/PairAndFactory.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract PAFXykCurveMissingEnumerableERC20Test is PairAndFactory, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}
