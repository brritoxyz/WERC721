// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {LSSVMPairETH} from "src/LSSVMPairETH.sol";
import {LSSVMPairMissingEnumerable} from "src/LSSVMPairMissingEnumerable.sol";
import {ILSSVMPairFactoryLike} from "src/interfaces/ILSSVMPairFactoryLike.sol";

contract LSSVMPairMissingEnumerableETH is
    LSSVMPairMissingEnumerable,
    LSSVMPairETH
{
    function pairVariant()
        public
        pure
        override
        returns (ILSSVMPairFactoryLike.PairVariant)
    {
        return ILSSVMPairFactoryLike.PairVariant.MISSING_ENUMERABLE_ETH;
    }
}
