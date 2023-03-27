// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithRoyalties} from "test/sudoswap/base/RouterSinglePoolWithRoyalties.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "test/sudoswap/mixins/UsingERC20.sol";

contract RSPWRExponentialCurveMissingEnumerableERC20Test is RouterSinglePoolWithRoyalties, UsingExponentialCurve, UsingMissingEnumerable, UsingERC20 {}
