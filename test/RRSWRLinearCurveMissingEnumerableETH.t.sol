// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterRobustSwapWithRoyalties} from "test/base/RouterRobustSwapWithRoyalties.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RRSWRLinearCurveMissingEnumerableETHTest is RouterRobustSwapWithRoyalties, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
