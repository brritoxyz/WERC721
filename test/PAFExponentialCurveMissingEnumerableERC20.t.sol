// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {PairAndFactory} from "test/base/PairAndFactory.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract PAFExponentialCurveMissingEnumerableERC20Test is PairAndFactory, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
