// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithRoyalties} from "test/sudoswap/base/RouterSinglePoolWithRoyalties.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RSPWRXykCurveEnumerableERC20Test is RouterSinglePoolWithRoyalties, UsingXykCurve, UsingEnumerable, UsingERC20 {}
