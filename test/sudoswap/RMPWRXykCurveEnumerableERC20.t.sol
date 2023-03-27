// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPoolWithRoyalties} from "test/sudoswap/base/RouterMultiPoolWithRoyalties.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RMPWRXykCurveEnumerableERC20Test is RouterMultiPoolWithRoyalties, UsingXykCurve, UsingEnumerable, UsingERC20 {}
