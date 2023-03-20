// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePoolWithRoyalties} from "test/base/RouterSinglePoolWithRoyalties.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RSPWRXykCurveEnumerableETHTest is RouterSinglePoolWithRoyalties, UsingXykCurve, UsingEnumerable, UsingETH {}
