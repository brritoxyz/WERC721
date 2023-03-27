// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {RouterSinglePoolWithRoyalties} from "test/sudoswap/base/RouterSinglePoolWithRoyalties.sol";
import {UsingLinearCurve} from "test/sudoswap/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/sudoswap/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/sudoswap/mixins/UsingETH.sol";

contract RSPWRLinearCurveEnumerableETHTest is RouterSinglePoolWithRoyalties, UsingLinearCurve, UsingEnumerable, UsingETH {}
