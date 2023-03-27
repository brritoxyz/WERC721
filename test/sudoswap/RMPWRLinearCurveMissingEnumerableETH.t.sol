// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPoolWithRoyalties} from "test/sudoswap/base/RouterMultiPoolWithRoyalties.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RMPWRLinearCurveMissingEnumerableETHTest is RouterMultiPoolWithRoyalties, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
