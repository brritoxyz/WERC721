// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {PairAndFactory} from "test/base/PairAndFactory.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract PAFXykCurveMissingEnumerableETHTest is PairAndFactory, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
