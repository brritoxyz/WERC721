// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePoolWithRoyalties} from "test/base/RouterSinglePoolWithRoyalties.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPWRLinearCurveEnumerableERC20Test is RouterSinglePoolWithRoyalties, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
