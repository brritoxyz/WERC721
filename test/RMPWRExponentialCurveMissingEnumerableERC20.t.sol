// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPoolWithRoyalties} from "test/base/RouterMultiPoolWithRoyalties.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPWRExponentialCurveMissingEnumerableERC20Test is RouterMultiPoolWithRoyalties, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
