// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePoolWithRoyalties} from "test/base/RouterSinglePoolWithRoyalties.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RSPWRExponentialCurveMissingEnumerableERC20Test is RouterSinglePoolWithRoyalties, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
