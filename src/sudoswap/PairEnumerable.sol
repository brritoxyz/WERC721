// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {IERC721Enumerable} from "openzeppelin/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {Router} from "sudoswap/Router.sol";
import {Pair} from "src/sudoswap/Pair.sol";
import {IPairFactoryLike} from "src/interfaces/IPairFactoryLike.sol";

/**
    @title An NFT/Token pair for an NFT that implements ERC721Enumerable
    @author boredGenius and 0xmons
 */
abstract contract PairEnumerable is Pair {
    /// @inheritdoc Pair
    function _sendAnyNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256 numNFTs
    ) internal override {
        // Send NFTs to recipient
        // (we know NFT implements IERC721Enumerable so we just iterate)
        uint256 lastIndex = _nft.balanceOf(address(this)) - 1;
        for (uint256 i = 0; i < numNFTs; ) {
            uint256 nftId = IERC721Enumerable(address(_nft))
                .tokenOfOwnerByIndex(address(this), lastIndex);
            _nft.safeTransferFrom(address(this), nftRecipient, nftId);

            unchecked {
                --lastIndex;
                ++i;
            }
        }
    }

    /// @inheritdoc Pair
    function _sendSpecificNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256[] calldata nftIds
    ) internal override {
        // Send NFTs to recipient
        uint256 numNFTs = nftIds.length;
        for (uint256 i; i < numNFTs; ) {
            _nft.safeTransferFrom(address(this), nftRecipient, nftIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc Pair
    function getAllHeldIds() external view override returns (uint256[] memory) {
        IERC721 _nft = nft();
        uint256 numNFTs = _nft.balanceOf(address(this));
        uint256[] memory ids = new uint256[](numNFTs);
        for (uint256 i; i < numNFTs; ) {
            ids[i] = IERC721Enumerable(address(_nft)).tokenOfOwnerByIndex(
                address(this),
                i
            );

            unchecked {
                ++i;
            }
        }
        return ids;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @inheritdoc Pair
    function withdrawERC721(IERC721 a, uint256[] calldata nftIds)
        external
        override
        onlyOwner
    {
        uint256 numNFTs = nftIds.length;
        for (uint256 i; i < numNFTs; ) {
            a.safeTransferFrom(address(this), msg.sender, nftIds[i]);

            unchecked {
                ++i;
            }
        }

        emit NFTWithdrawal();
    }
}