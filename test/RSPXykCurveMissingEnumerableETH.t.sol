// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePool} from "test/base/RouterSinglePool.sol";
import {UsingXykCurve} from "test/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RSPXykCurveMissingEnumerableETHTest is RouterSinglePool, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
