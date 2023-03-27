// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterRobustSwapWithRoyalties} from "test/sudoswap/base/RouterRobustSwapWithRoyalties.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RRSWRLinearCurveMissingEnumerableETHTest is RouterRobustSwapWithRoyalties, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
