// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {PairETH} from "sudoswap/PairETH.sol";
import {PairEnumerable} from "sudoswap/PairEnumerable.sol";
import {IPairFactoryLike} from "src/interfaces/IPairFactoryLike.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is ETH
    @author boredGenius and 0xmons
 */
contract PairEnumerableETH is PairEnumerable, PairETH {
    /**
        @notice Returns the Pair type
     */
    function pairVariant()
        public
        pure
        override
        returns (IPairFactoryLike.PairVariant)
    {
        return IPairFactoryLike.PairVariant.ENUMERABLE_ETH;
    }
}
