// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {PairETH} from "sudoswap/PairETH.sol";
import {PairMissingEnumerable} from "sudoswap/PairMissingEnumerable.sol";
import {IPairFactoryLike} from "src/interfaces/IPairFactoryLike.sol";

contract PairMissingEnumerableETH is
    PairMissingEnumerable,
    PairETH
{
    function pairVariant()
        public
        pure
        override
        returns (IPairFactoryLike.PairVariant)
    {
        return IPairFactoryLike.PairVariant.MISSING_ENUMERABLE_ETH;
    }
}
