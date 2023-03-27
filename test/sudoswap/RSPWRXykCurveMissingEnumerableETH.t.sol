// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithRoyalties} from "test/sudoswap/base/RouterSinglePoolWithRoyalties.sol";
import {UsingXykCurve} from "test/sudoswap/mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "test/sudoswap/mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RSPWRXykCurveMissingEnumerableETHTest is RouterSinglePoolWithRoyalties, UsingXykCurve, UsingMissingEnumerable, UsingETH {}
