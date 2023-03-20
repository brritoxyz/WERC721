// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPoolWithRoyalties} from "test/base/RouterMultiPoolWithRoyalties.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RMPWRXykCurveEnumerableETHTest is RouterMultiPoolWithRoyalties, UsingXykCurve, UsingEnumerable, UsingETH {}
