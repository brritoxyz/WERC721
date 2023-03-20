// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {LSSVMPairERC20} from "./LSSVMPairERC20.sol";
import {LSSVMPairMissingEnumerable} from "./LSSVMPairMissingEnumerable.sol";
import {ILSSVMPairFactoryLike} from "src/interfaces/ILSSVMPairFactoryLike.sol";

contract LSSVMPairMissingEnumerableERC20 is
    LSSVMPairMissingEnumerable,
    LSSVMPairERC20
{
    function pairVariant()
        public
        pure
        override
        returns (ILSSVMPairFactoryLike.PairVariant)
    {
        return ILSSVMPairFactoryLike.PairVariant.MISSING_ENUMERABLE_ERC20;
    }
}
