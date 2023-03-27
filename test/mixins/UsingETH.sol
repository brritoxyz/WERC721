// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {ICurve} from "src/interfaces/ICurve.sol";
import {Pair} from "src/sudoswap/Pair.sol";
import {PairFactory} from "src/MoonPairFactory.sol";
import {Router} from "sudoswap/Router.sol";
import {Router2} from "sudoswap/Router2.sol";
import {PairETH} from "sudoswap/PairETH.sol";
import {Configurable} from "./Configurable.sol";
import {RouterCaller} from "./RouterCaller.sol";

abstract contract UsingETH is Configurable, RouterCaller {
    function modifyInputAmount(uint256 inputAmount)
        public
        pure
        override
        returns (uint256)
    {
        return inputAmount;
    }

    function getBalance(address a) public view override returns (uint256) {
        return a.balance;
    }

    function sendTokens(Pair pair, uint256 amount) public override {
        payable(address(pair)).transfer(amount);
    }

    function setupPair(
        PairFactory factory,
        IERC721 nft,
        ICurve bondingCurve,
        address payable assetRecipient,
        Pair.PoolType poolType,
        uint128 delta,
        uint96 fee,
        uint128 spotPrice,
        uint256[] memory _idList,
        uint256,
        address
    ) public payable override returns (Pair) {
        PairETH pair = factory.createPairETH{value: msg.value}(
            nft,
            bondingCurve,
            assetRecipient,
            poolType,
            delta,
            fee,
            spotPrice,
            _idList
        );
        return pair;
    }

    function withdrawTokens(Pair pair) public override {
        PairETH(payable(address(pair))).withdrawAllETH();
    }

    function withdrawProtocolFees(PairFactory factory) public override {
        factory.withdrawETHProtocolFees();
    }

    function swapTokenForAnyNFTs(
        Router router,
        Router.PairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.swapETHForAnyNFTs{value: msg.value}(
                swapList,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function swapTokenForSpecificNFTs(
        Router router,
        Router.PairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.swapETHForSpecificNFTs{value: msg.value}(
                swapList,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function swapNFTsForAnyNFTsThroughToken(
        Router router,
        Router.NFTsForAnyNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.swapNFTsForAnyNFTsThroughETH{value: msg.value}(
                trade,
                minOutput,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function swapNFTsForSpecificNFTsThroughToken(
        Router router,
        Router.NFTsForSpecificNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.swapNFTsForSpecificNFTsThroughETH{value: msg.value}(
                trade,
                minOutput,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForAnyNFTs(
        Router router,
        Router.RobustPairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.robustSwapETHForAnyNFTs{value: msg.value}(
                swapList,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTs(
        Router router,
        Router.RobustPairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.robustSwapETHForSpecificNFTs{value: msg.value}(
                swapList,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTsAndNFTsForTokens(
        Router router,
        Router.RobustPairNFTsFoTokenAndTokenforNFTsTrade calldata params
    ) public payable override returns (uint256, uint256) {
        return
            router.robustSwapETHForSpecificNFTsAndNFTsToToken{value: msg.value}(
                params
            );
    }

    function buyAndSellWithPartialFill(
        Router2 router,
        Router2.PairSwapSpecificPartialFill[] calldata buyList,
        Router2.PairSwapSpecificPartialFillForToken[] calldata sellList
    ) public payable override returns (uint256) {
      return router.robustBuySellWithETHAndPartialFill{value: msg.value}(
        buyList, sellList
      );
    }

    function swapETHForSpecificNFTs(
        Router2 router,
        Router2.RobustPairSwapSpecific[] calldata buyList
    ) public payable override returns (uint256) {
      return router.swapETHForSpecificNFTs{value: msg.value}(buyList);
    }
}
