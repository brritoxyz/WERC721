// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPoolWithRoyalties} from "test/sudoswap/base/RouterMultiPoolWithRoyalties.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RMPWRExponentialCurveMissingEnumerableERC20Test is RouterMultiPoolWithRoyalties, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
