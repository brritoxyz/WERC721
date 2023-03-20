// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {RouterSinglePoolWithRoyalties} from "test/base/RouterSinglePoolWithRoyalties.sol";
import {UsingLinearCurve} from "test/mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "test/mixins/UsingEnumerable.sol";
import {UsingETH} from "test/mixins/UsingETH.sol";

contract RSPWRLinearCurveEnumerableETHTest is RouterSinglePoolWithRoyalties, UsingLinearCurve, UsingEnumerable, UsingETH {}
