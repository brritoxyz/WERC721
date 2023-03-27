// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPoolWithRoyalties} from "test/sudoswap/base/RouterMultiPoolWithRoyalties.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RMPWRExponentialCurveEnumerableETHTest is RouterMultiPoolWithRoyalties, UsingExponentialCurve, UsingEnumerable, UsingETH {}
