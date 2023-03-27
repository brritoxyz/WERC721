// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePool} from "test/sudoswap/base/RouterSinglePool.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RSPXykCurveMissingEnumerableETHTest is RouterSinglePool, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
