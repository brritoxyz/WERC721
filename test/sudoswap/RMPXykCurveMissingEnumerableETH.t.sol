// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterMultiPool} from "test/sudoswap/base/RouterMultiPool.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RMPXykCurveMissingEnumerableETHTest is RouterMultiPool, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
