// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterMultiPoolWithRoyalties} from "test/base/RouterMultiPoolWithRoyalties.sol";
import {UsingExponentialCurve} from "test/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RMPWRExponentialCurveMissingEnumerableETHTest is RouterMultiPoolWithRoyalties, UsingExponentialCurve, UsingMissingEnumerable, UsingETH {}
