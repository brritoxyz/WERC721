// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPoolWithRoyalties} from "test/base/RouterMultiPoolWithRoyalties.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingERC20} from "test/mixins/UsingERC20.sol";

contract RMPWRLinearCurveEnumerableERC20Test is RouterMultiPoolWithRoyalties, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
