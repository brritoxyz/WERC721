// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPoolWithRoyalties} from "test/base/RouterMultiPoolWithRoyalties.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPWRXykCurveEnumerableERC20Test is RouterMultiPoolWithRoyalties, UsingXykCurve, UsingEnumerable, UsingERC20 {}
