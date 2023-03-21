// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {LinearCurve} from "src/bonding-curves/LinearCurve.sol";
import {Test721Enumerable} from "test/mocks/Test721Enumerable.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {ICurve} from "src/interfaces/ICurve.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Configurable} from "./Configurable.sol";

abstract contract UsingLinearCurve is Configurable {
    function setupCurve() public override returns (ICurve) {
        return new LinearCurve();
    }

    function modifyDelta(uint64 delta) public pure override returns (uint64) {
        return delta;
    }

    function modifySpotPrice(uint56 spotPrice)
        public
        pure
        override
        returns (uint56)
    {
        return spotPrice;
    }

        // Return 1 eth as spot price and 0.1 eth as the delta scaling
    function getParamsForPartialFillTest() public pure override returns (uint128 spotPrice, uint128 delta) {
      return (10**18, 10**17);
    }
}
