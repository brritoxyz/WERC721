// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {PairAndFactory} from "test/sudoswap/base/PairAndFactory.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract PAFXykCurveMissingEnumerableETHTest is PairAndFactory, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
