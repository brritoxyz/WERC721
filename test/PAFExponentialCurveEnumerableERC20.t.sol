// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/base/PairAndFactory.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract PAFExponentialCurveEnumerableERC20Test is PairAndFactory, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
