// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {DSTest} from "ds-test/test.sol";
import {ERC721Holder} from "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

import {ICurve} from "src/interfaces/ICurve.sol";
import {PairFactory} from "sudoswap/PairFactory.sol";
import {Pair} from "src/sudoswap/Pair.sol";
import {PairETH} from "sudoswap/PairETH.sol";
import {PairERC20} from "sudoswap/PairERC20.sol";
import {PairEnumerableETH} from "sudoswap/PairEnumerableETH.sol";
import {PairMissingEnumerableETH} from "sudoswap/PairMissingEnumerableETH.sol";
import {PairEnumerableERC20} from "sudoswap/PairEnumerableERC20.sol";
import {PairMissingEnumerableERC20} from "sudoswap/PairMissingEnumerableERC20.sol";
import {Router} from "sudoswap/Router.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {Configurable} from "test/mixins/Configurable.sol";
import {RouterCaller} from "test/mixins/RouterCaller.sol";

abstract contract RouterSinglePoolWithAssetRecipient is
    DSTest,
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    PairFactory factory;
    Router router;
    Pair sellPair; // Gives NFTs, takes in tokens
    Pair buyPair; // Takes in NFTs, gives tokens
    address payable constant feeRecipient = payable(address(69));
    address payable constant sellPairRecipient = payable(address(1));
    address payable constant buyPairRecipient = payable(address(2));
    uint256 constant protocolFeeMultiplier = 0;
    uint256 constant numInitialNFTs = 10;

    function setUp() public {
        bondingCurve = setupCurve();
        test721 = setup721();
        PairEnumerableETH enumerableETHTemplate = new PairEnumerableETH();
        PairMissingEnumerableETH missingEnumerableETHTemplate = new PairMissingEnumerableETH();
        PairEnumerableERC20 enumerableERC20Template = new PairEnumerableERC20();
        PairMissingEnumerableERC20 missingEnumerableERC20Template = new PairMissingEnumerableERC20();
        factory = new PairFactory(
            enumerableETHTemplate,
            missingEnumerableETHTemplate,
            enumerableERC20Template,
            missingEnumerableERC20Template,
            feeRecipient,
            protocolFeeMultiplier
        );
        router = new Router(factory);
        factory.setBondingCurveAllowed(bondingCurve, true);
        factory.setRouterAllowed(router, true);

        // set NFT approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);

        // Setup pair parameters
        uint128 delta = 0 ether;
        uint128 spotPrice = 1 ether;
        uint256[] memory sellIDList = new uint256[](numInitialNFTs);
        uint256[] memory buyIDList = new uint256[](numInitialNFTs);
        for (uint256 i = 1; i <= 2 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
            if (i <= numInitialNFTs) {
                sellIDList[i - 1] = i;
            } else {
                buyIDList[i - numInitialNFTs - 1] = i;
            }
        }

        // Create a sell pool with a spot price of 1 eth, 10 NFTs, and no price increases
        // All stuff gets sent to assetRecipient
        sellPair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            sellPairRecipient,
            Pair.PoolType.NFT,
            modifyDelta(uint64(delta)),
            0,
            spotPrice,
            sellIDList,
            10 ether,
            address(router)
        );

        // Create a buy pool with a spot price of 1 eth, 10 NFTs, and no price increases
        // All stuff gets sent to assetRecipient
        buyPair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            buyPairRecipient,
            Pair.PoolType.TOKEN,
            modifyDelta(uint64(delta)),
            0,
            spotPrice,
            buyIDList,
            10 ether,
            address(router)
        );

        // mint extra NFTs to this contract (i.e. to be held by the caller)
        for (uint256 i = 2 * numInitialNFTs + 1; i <= 3 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
    }

    function test_swapTokenForSingleAnyNFT() public {
        Router.PairSwapAny[]
            memory swapList = new Router.PairSwapAny[](1);
        swapList[0] = Router.PairSwapAny({pair: sellPair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, ) = sellPair.getBuyNFTQuote(1);
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        assertEq(getBalance(sellPairRecipient), inputAmount);
    }

    function test_swapTokenForSingleSpecificNFT() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({
            pair: sellPair,
            nftIds: nftIds
        });
        uint256 inputAmount;
        (, , , inputAmount, ) = sellPair.getBuyNFTQuote(1);
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        assertEq(getBalance(sellPairRecipient), inputAmount);
    }

    function test_swapSingleNFTForToken() public {
        (, , , uint256 outputAmount, ) = buyPair.getSellNFTQuote(1);
        uint256 beforeBuyPairNFTBalance = test721.balanceOf(address(buyPair));
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs * 2 + 1;
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            outputAmount,
            payable(address(this)),
            block.timestamp
        );
        assertEq(test721.balanceOf(buyPairRecipient), 1);
        // Pool should still keep track of the same number of NFTs prior to the swap
        // because we sent the NFT to the asset recipient (and not the pair)
        uint256 afterBuyPairNFTBalance = (buyPair.getAllHeldIds()).length;
        assertEq(beforeBuyPairNFTBalance, afterBuyPairNFTBalance);
    }

    function test_swapSingleNFTForAnyNFT() public {
        // construct NFT to Token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = 2 * numInitialNFTs + 1;
        Router.PairSwapSpecific[]
            memory nftToTokenSwapList = new Router.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: sellNFTIds
        });
        // construct Token to NFT swap list
        Router.PairSwapAny[]
            memory tokenToNFTSwapList = new Router.PairSwapAny[](1);
        tokenToNFTSwapList[0] = Router.PairSwapAny({
            pair: sellPair,
            numItems: 1
        });
        uint256 sellAmount;
        (, , , sellAmount, ) = sellPair.getBuyNFTQuote(1);
        // Note: we send a little bit of tokens with the call because the exponential curve increases price ever so slightly
        uint256 inputAmount = 0.1 ether;
        this.swapNFTsForAnyNFTsThroughToken{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            Router.NFTsForAnyNFTsTrade({
                nftToTokenTrades: nftToTokenSwapList,
                tokenToNFTTrades: tokenToNFTSwapList
            }),
            0,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        assertEq(test721.balanceOf(buyPairRecipient), 1);
        assertEq(getBalance(sellPairRecipient), sellAmount);
    }

    function test_swapSingleNFTForSpecificNFT() public {
        // construct NFT to token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = 2 * numInitialNFTs + 1;
        Router.PairSwapSpecific[]
            memory nftToTokenSwapList = new Router.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: sellNFTIds
        });

        // construct token to NFT swap list
        uint256[] memory buyNFTIds = new uint256[](1);
        buyNFTIds[0] = numInitialNFTs;
        Router.PairSwapSpecific[]
            memory tokenToNFTSwapList = new Router.PairSwapSpecific[](1);
        tokenToNFTSwapList[0] = Router.PairSwapSpecific({
            pair: sellPair,
            nftIds: buyNFTIds
        });
        uint256 sellAmount;
        (, , , sellAmount, ) = sellPair.getBuyNFTQuote(1);
        // Note: we send a little bit of tokens with the call because the exponential curve increases price ever so slightly
        uint256 inputAmount = 0.1 ether;
        this.swapNFTsForSpecificNFTsThroughToken{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            Router.NFTsForSpecificNFTsTrade({
                nftToTokenTrades: nftToTokenSwapList,
                tokenToNFTTrades: tokenToNFTSwapList
            }),
            0,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        assertEq(test721.balanceOf(buyPairRecipient), 1);
        assertEq(getBalance(sellPairRecipient), sellAmount);
    }

    function test_swapTokenforAny5NFTs() public {
        Router.PairSwapAny[]
            memory swapList = new Router.PairSwapAny[](1);
        swapList[0] = Router.PairSwapAny({pair: sellPair, numItems: 5});
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, ) = sellPair.getBuyNFTQuote(5);
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        uint256 endBalance = test721.balanceOf(address(this));
        require((endBalance - startBalance) == 5, "Too few NFTs acquired");
        assertEq(getBalance(sellPairRecipient), inputAmount);
    }

    function test_swapTokenforSpecific5NFTs() public {
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        uint256[] memory nftIds = new uint256[](5);
        nftIds[0] = 1;
        nftIds[1] = 2;
        nftIds[2] = 3;
        nftIds[3] = 4;
        nftIds[4] = 5;
        swapList[0] = Router.PairSwapSpecific({
            pair: sellPair,
            nftIds: nftIds
        });
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, ) = sellPair.getBuyNFTQuote(5);
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        uint256 endBalance = test721.balanceOf(address(this));
        require((endBalance - startBalance) == 5, "Too few NFTs acquired");
        assertEq(getBalance(sellPairRecipient), inputAmount);
    }

    function test_swap5NFTsForToken() public {
        (, , , uint256 outputAmount, ) = buyPair.getSellNFTQuote(5);
        uint256 beforeBuyPairNFTBalance = test721.balanceOf(address(buyPair));
        uint256[] memory nftIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            nftIds[i] = 2 * numInitialNFTs + i + 1;
        }
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            outputAmount,
            payable(address(this)),
            block.timestamp
        );
        assertEq(test721.balanceOf(buyPairRecipient), 5);
        // Pool should still keep track of the same number of NFTs prior to the swap
        // because we sent the NFT to the asset recipient (and not the pair)
        uint256 afterBuyPairNFTBalance = (buyPair.getAllHeldIds()).length;
        assertEq(beforeBuyPairNFTBalance, afterBuyPairNFTBalance);
    }

    function test_swapSingleNFTForTokenWithProtocolFee() public {
        // Set protocol fee to be 10%
        factory.changeProtocolFeeMultiplier(0.1e18);
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs * 2 + 1;
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: nftIds
        });
        (, , , uint256 outputAmount, ) = buyPair.getSellNFTQuote(1);
        uint256 output = router.swapNFTsForToken(
            swapList,
            outputAmount,
            payable(address(this)),
            block.timestamp
        );
        // User gets 90% of the tokens (which is output) and the other 10% goes to the factory
        assertEq(getBalance(address(factory)), output / 9);
    }

    function test_swapTokenForSingleSpecificNFTWithProtocolFee() public {
        // Set protocol fee to be 10%
        factory.changeProtocolFeeMultiplier(0.1e18);
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({
            pair: sellPair,
            nftIds: nftIds
        });
        uint256 inputAmount;
        (, , , inputAmount, ) = sellPair.getBuyNFTQuote(1);
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        // Assert 90% and 10% split of the buy amount between sellPairRecipient and the factory
        assertEq(getBalance(address(factory)), inputAmount / 11);
        assertEq(
            getBalance(sellPairRecipient) + getBalance(address(factory)),
            inputAmount
        );
    }

    function test_swapTokenForSingleAnyNFTWithProtocolFee() public {
        // Set protocol fee to be 10%
        factory.changeProtocolFeeMultiplier(0.1e18);
        Router.PairSwapAny[]
            memory swapList = new Router.PairSwapAny[](1);
        swapList[0] = Router.PairSwapAny({pair: sellPair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, ) = sellPair.getBuyNFTQuote(1);
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        // Assert 90% and 10% split of the buy amount between sellPairRecipient and the factory
        assertEq(getBalance(address(factory)), inputAmount / 11);
        assertEq(
            getBalance(sellPairRecipient) + getBalance(address(factory)),
            inputAmount
        );
    }
}
