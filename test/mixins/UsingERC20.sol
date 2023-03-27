// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {NoArbBondingCurve} from "test/base/NoArbBondingCurve.sol";
import {Pair} from "src/sudoswap/Pair.sol";
import {PairERC20} from "sudoswap/PairERC20.sol";
import {Router} from "sudoswap/Router.sol";
import {Router2} from "sudoswap/Router2.sol";
import {Test20} from "test/mocks/Test20.sol";
import {IMintable} from "test/interfaces/IMintable.sol";
import {PairFactory} from "src/MoonPairFactory.sol";
import {ICurve} from "src/interfaces/ICurve.sol";
import {Configurable} from "test/mixins/Configurable.sol";
import {RouterCaller} from "test/mixins/RouterCaller.sol";

abstract contract UsingERC20 is Configurable, RouterCaller {
    using SafeTransferLib for ERC20;
    ERC20 test20;

    function modifyInputAmount(uint256) public pure override returns (uint256) {
        return 0;
    }

    function getBalance(address a) public view override returns (uint256) {
        return test20.balanceOf(a);
    }

    function sendTokens(Pair pair, uint256 amount) public override {
        test20.safeTransfer(address(pair), amount);
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
        uint256 initialTokenBalance,
        address routerAddress
    ) public payable override returns (Pair) {
        // create ERC20 token if not already deployed
        if (address(test20) == address(0)) {
            test20 = new Test20();
        }

        // set approvals for factory and router
        test20.approve(address(factory), type(uint256).max);
        test20.approve(routerAddress, type(uint256).max);

        // mint enough tokens to caller
        IMintable(address(test20)).mint(address(this), 1000 ether);

        // initialize the pair
        Pair pair = factory.createPairERC20(
            PairFactory.CreateERC20PairParams(
                test20,
                nft,
                bondingCurve,
                assetRecipient,
                poolType,
                delta,
                fee,
                spotPrice,
                _idList,
                initialTokenBalance
            )
        );

        // Set approvals for pair
        test20.approve(address(pair), type(uint256).max);

        return pair;
    }

    function withdrawTokens(Pair pair) public override {
        uint256 total = test20.balanceOf(address(pair));
        PairERC20(address(pair)).withdrawERC20(test20, total);
    }

    function withdrawProtocolFees(PairFactory factory) public override {
        factory.withdrawERC20ProtocolFees(
            test20,
            test20.balanceOf(address(factory))
        );
    }

    function swapTokenForAnyNFTs(
        Router router,
        Router.PairSwapAny[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.swapERC20ForAnyNFTs(
                swapList,
                inputAmount,
                nftRecipient,
                deadline
            );
    }

    function swapTokenForSpecificNFTs(
        Router router,
        Router.PairSwapSpecific[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.swapERC20ForSpecificNFTs(
                swapList,
                inputAmount,
                nftRecipient,
                deadline
            );
    }

    function swapNFTsForAnyNFTsThroughToken(
        Router router,
        Router.NFTsForAnyNFTsTrade calldata trade,
        uint256 minOutput,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.swapNFTsForAnyNFTsThroughERC20(
                trade,
                inputAmount,
                minOutput,
                nftRecipient,
                deadline
            );
    }

    function swapNFTsForSpecificNFTsThroughToken(
        Router router,
        Router.NFTsForSpecificNFTsTrade calldata trade,
        uint256 minOutput,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.swapNFTsForSpecificNFTsThroughERC20(
                trade,
                inputAmount,
                minOutput,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForAnyNFTs(
        Router router,
        Router.RobustPairSwapAny[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.robustSwapERC20ForAnyNFTs(
                swapList,
                inputAmount,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTs(
        Router router,
        Router.RobustPairSwapSpecific[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.robustSwapERC20ForSpecificNFTs(
                swapList,
                inputAmount,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTsAndNFTsForTokens(
        Router router,
        Router.RobustPairNFTsFoTokenAndTokenforNFTsTrade calldata params
    ) public payable override returns (uint256, uint256) {
        return router.robustSwapERC20ForSpecificNFTsAndNFTsToToken(params);
    }

    function buyAndSellWithPartialFill(
        Router2,
        Router2.PairSwapSpecificPartialFill[] calldata,
        Router2.PairSwapSpecificPartialFillForToken[] calldata
    ) public payable override returns (uint256) {
        require(false, "Unimplemented");

        return 0;
    }

    function swapETHForSpecificNFTs(
        Router2,
        Router2.RobustPairSwapSpecific[] calldata
    ) public payable override returns (uint256) {
        require(false, "Unimplemented");

        return 0;
    }
}
