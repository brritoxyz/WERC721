// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePoolWithRoyalties} from "test/base/RouterSinglePoolWithRoyalties.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPWRExponentialCurveEnumerableERC20Test is RouterSinglePoolWithRoyalties, UsingExponentialCurve, UsingEnumerable, UsingERC20 {}
