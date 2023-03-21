// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {PairERC20} from "sudoswap/PairERC20.sol";
import {PairEnumerable} from "sudoswap/PairEnumerable.sol";
import {IPairFactoryLike} from "src/interfaces/IPairFactoryLike.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is an ERC20
    @author boredGenius and 0xmons
 */
contract PairEnumerableERC20 is PairEnumerable, PairERC20 {
    /**
        @notice Returns the Pair type
     */
    function pairVariant()
        public
        pure
        override
        returns (IPairFactoryLike.PairVariant)
    {
        return IPairFactoryLike.PairVariant.ENUMERABLE_ERC20;
    }
}
