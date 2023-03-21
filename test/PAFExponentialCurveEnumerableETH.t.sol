// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/base/PairAndFactory.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract PAFExponentialCurveEnumerableETHTest is PairAndFactory, UsingExponentialCurve, UsingEnumerable, UsingETH {}
