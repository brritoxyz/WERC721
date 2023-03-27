// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithRoyalties} from "test/sudoswap/base/RouterSinglePoolWithRoyalties.sol";
import {UsingExponentialCurve} from "test/sudoswap/mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RSPWRExponentialCurveMissingEnumerableETHTest is RouterSinglePoolWithRoyalties, UsingExponentialCurve, UsingMissingEnumerable, UsingETH {}
