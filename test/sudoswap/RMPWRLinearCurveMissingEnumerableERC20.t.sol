// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPoolWithRoyalties} from "test/sudoswap/base/RouterMultiPoolWithRoyalties.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RMPWRLinearCurveMissingEnumerableERC20Test is RouterMultiPoolWithRoyalties, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}
