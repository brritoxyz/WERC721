// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPoolWithRoyalties} from "test/base/RouterMultiPoolWithRoyalties.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPWRXykCurveMissingEnumerableERC20Test is RouterMultiPoolWithRoyalties, UsingXykCurve, UsingMissingEnumerable, UsingERC20 {}