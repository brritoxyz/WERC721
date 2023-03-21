// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {PairERC20} from "sudoswap/PairERC20.sol";
import {PairMissingEnumerable} from "sudoswap/PairMissingEnumerable.sol";
import {IPairFactoryLike} from "src/interfaces/IPairFactoryLike.sol";

contract PairMissingEnumerableERC20 is
    PairMissingEnumerable,
    PairERC20
{
    function pairVariant()
        public
        pure
        override
        returns (IPairFactoryLike.PairVariant)
    {
        return IPairFactoryLike.PairVariant.MISSING_ENUMERABLE_ERC20;
    }
}
