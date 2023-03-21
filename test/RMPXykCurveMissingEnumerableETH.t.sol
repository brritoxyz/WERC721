// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/base/RouterMultiPool.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RMPXykCurveMissingEnumerableETHTest is RouterMultiPool, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
