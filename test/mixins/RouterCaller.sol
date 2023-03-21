// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {Router} from "sudoswap/Router.sol";
import {Router2} from "sudoswap/Router2.sol";

abstract contract RouterCaller {
    function swapTokenForAnyNFTs(
        Router router,
        Router.PairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function swapTokenForSpecificNFTs(
        Router router,
        Router.PairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function swapNFTsForAnyNFTsThroughToken(
        Router router,
        Router.NFTsForAnyNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function swapNFTsForSpecificNFTsThroughToken(
        Router router,
        Router.NFTsForSpecificNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function robustSwapTokenForAnyNFTs(
        Router router,
        Router.RobustPairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function robustSwapTokenForSpecificNFTs(
        Router router,
        Router.RobustPairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function robustSwapTokenForSpecificNFTsAndNFTsForTokens(
        Router router,
        Router.RobustPairNFTsFoTokenAndTokenforNFTsTrade calldata params
    ) public payable virtual returns (uint256, uint256);

    function buyAndSellWithPartialFill(
        Router2 router,
        Router2.PairSwapSpecificPartialFill[] calldata buyList,
        Router2.PairSwapSpecificPartialFillForToken[] calldata sellList
    ) public payable virtual returns (uint256);

    function swapETHForSpecificNFTs(
        Router2 router,
        Router2.RobustPairSwapSpecific[] calldata buyList
    ) public payable virtual returns (uint256);
}
