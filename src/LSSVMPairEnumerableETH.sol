// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {LSSVMPairETH} from "src/LSSVMPairETH.sol";
import {LSSVMPairEnumerable} from "src/LSSVMPairEnumerable.sol";
import {ILSSVMPairFactoryLike} from "src/interfaces/ILSSVMPairFactoryLike.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is ETH
    @author boredGenius and 0xmons
 */
contract LSSVMPairEnumerableETH is LSSVMPairEnumerable, LSSVMPairETH {
    /**
        @notice Returns the LSSVMPair type
     */
    function pairVariant()
        public
        pure
        override
        returns (ILSSVMPairFactoryLike.PairVariant)
    {
        return ILSSVMPairFactoryLike.PairVariant.ENUMERABLE_ETH;
    }
}
