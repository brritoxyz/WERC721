// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {DSTest} from "ds-test/test.sol";
import {ERC721Holder} from "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

import {Pair} from "sudoswap/Pair.sol";
import {PairETH} from "sudoswap/PairETH.sol";
import {PairERC20} from "sudoswap/PairERC20.sol";
import {PairEnumerableERC20} from "sudoswap/PairEnumerableERC20.sol";
import {PairMissingEnumerableERC20} from "sudoswap/PairMissingEnumerableERC20.sol";
import {Router} from "sudoswap/Router.sol";
import {IERC721Mintable} from "test/sudoswap/interfaces/IERC721Mintable.sol";
import {Configurable} from "test/sudoswap/mixins/Configurable.sol";
import {RouterCaller} from "test/sudoswap/mixins/RouterCaller.sol";
import {ICurve} from "src/interfaces/ICurve.sol";
import {PairFactory} from "src/MoonPairFactory.sol";
import {PairEnumerableETH} from "src/MoonPairEnumerableETH.sol";
import {PairMissingEnumerableETH} from "src/MoonPairMissingEnumerableETH.sol";
import {Moon} from "src/Moon.sol";

abstract contract RouterSinglePool is
    DSTest,
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    PairFactory factory;
    Router router;
    Pair pair;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;
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

        // Deploy and configure Moon contract
        Moon moon = new Moon(address(this));
        moon.setFactory(address(factory));
        factory.setMoon(moon);

        // set NFT approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);

        // Setup pair parameters
        uint128 delta = 0 ether;
        uint128 spotPrice = 1 ether;
        uint256[] memory idList = new uint256[](numInitialNFTs);
        for (uint256 i = 1; i <= numInitialNFTs; i++) {
            test721.mint(address(this), i);
            idList[i - 1] = i;
        }

        // Create a pair with a spot price of 1 eth, 10 NFTs, and no price increases
        pair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            Pair.PoolType.TRADE,
            modifyDelta(uint64(delta)),
            0,
            spotPrice,
            idList,
            10 ether,
            address(router)
        );

        // mint extra NFTs to this contract (i.e. to be held by the caller)
        for (uint256 i = numInitialNFTs + 1; i <= 2 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
    }

    function test_swapTokenForSingleAnyNFT() public {
        Router.PairSwapAny[] memory swapList = new Router.PairSwapAny[](1);
        swapList[0] = Router.PairSwapAny({pair: pair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function test_swapTokenForSingleSpecificNFT() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({pair: pair, nftIds: nftIds});
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function test_swapSingleNFTForToken() public {
        (, , , uint256 outputAmount, ) = pair.getSellNFTQuote(1);
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({pair: pair, nftIds: nftIds});
        router.swapNFTsForToken(
            swapList,
            outputAmount,
            payable(address(this)),
            block.timestamp
        );
    }

    function testGas_swapSingleNFTForToken5Times() public {
        for (uint256 i = 1; i <= 5; i++) {
            (, , , uint256 outputAmount, ) = pair.getSellNFTQuote(1);
            uint256[] memory nftIds = new uint256[](1);
            nftIds[0] = numInitialNFTs + i;
            Router.PairSwapSpecific[]
                memory swapList = new Router.PairSwapSpecific[](1);
            swapList[0] = Router.PairSwapSpecific({pair: pair, nftIds: nftIds});
            router.swapNFTsForToken(
                swapList,
                outputAmount,
                payable(address(this)),
                block.timestamp
            );
        }
    }

    function test_swapSingleNFTForAnyNFT() public {
        // construct NFT to Token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        Router.PairSwapSpecific[]
            memory nftToTokenSwapList = new Router.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = Router.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        // construct Token to NFT swap list
        Router.PairSwapAny[]
            memory tokenToNFTSwapList = new Router.PairSwapAny[](1);
        tokenToNFTSwapList[0] = Router.PairSwapAny({pair: pair, numItems: 1});

        // NOTE: We send some tokens (more than enough) to cover the protocol fee needed
        uint256 inputAmount = 0.01 ether;
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
    }

    function test_swapSingleNFTForSpecificNFT() public {
        // construct NFT to token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        Router.PairSwapSpecific[]
            memory nftToTokenSwapList = new Router.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = Router.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        // construct token to NFT swap list
        uint256[] memory buyNFTIds = new uint256[](1);
        buyNFTIds[0] = 1;
        Router.PairSwapSpecific[]
            memory tokenToNFTSwapList = new Router.PairSwapSpecific[](1);
        tokenToNFTSwapList[0] = Router.PairSwapSpecific({
            pair: pair,
            nftIds: buyNFTIds
        });

        // NOTE: We send some tokens (more than enough) to cover the protocol fee
        uint256 inputAmount = 0.01 ether;
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
    }

    function test_swapTokenforAny5NFTs() public {
        Router.PairSwapAny[] memory swapList = new Router.PairSwapAny[](1);
        swapList[0] = Router.PairSwapAny({pair: pair, numItems: 5});
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(5);
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
        swapList[0] = Router.PairSwapSpecific({pair: pair, nftIds: nftIds});
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(5);
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
    }

    function test_swap5NFTsForToken() public {
        (, , , uint256 outputAmount, ) = pair.getSellNFTQuote(5);
        uint256[] memory nftIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            nftIds[i] = numInitialNFTs + i + 1;
        }
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({pair: pair, nftIds: nftIds});
        router.swapNFTsForToken(
            swapList,
            outputAmount,
            payable(address(this)),
            block.timestamp
        );
    }

    function testFail_swapTokenForSingleAnyNFTSlippage() public {
        Router.PairSwapAny[] memory swapList = new Router.PairSwapAny[](1);
        swapList[0] = Router.PairSwapAny({pair: pair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
        inputAmount = inputAmount - 1 wei;
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function testFail_swapTokenForSingleSpecificNFTSlippage() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({pair: pair, nftIds: nftIds});
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
        inputAmount = inputAmount - 1 wei;
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function testFail_swapSingleNFTForNonexistentToken() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({pair: pair, nftIds: nftIds});
        uint256 sellAmount;
        (, , , sellAmount, ) = pair.getSellNFTQuote(1);
        sellAmount = sellAmount + 1 wei;
        router.swapNFTsForToken(
            swapList,
            sellAmount,
            payable(address(this)),
            block.timestamp
        );
    }

    function testFail_swapTokenForAnyNFTsPastBalance() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        Router.PairSwapAny[] memory swapList = new Router.PairSwapAny[](1);
        swapList[0] = Router.PairSwapAny({
            pair: pair,
            numItems: test721.balanceOf(address(pair)) + 1
        });
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(
            test721.balanceOf(address(pair)) + 1
        );
        inputAmount = inputAmount + 1 wei;
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function testFail_swapSingleNFTForTokenWithEmptyList() public {
        uint256[] memory nftIds = new uint256[](0);
        Router.PairSwapSpecific[]
            memory swapList = new Router.PairSwapSpecific[](1);
        swapList[0] = Router.PairSwapSpecific({pair: pair, nftIds: nftIds});
        uint256 sellAmount;
        (, , , sellAmount, ) = pair.getSellNFTQuote(1);
        sellAmount = sellAmount + 1 wei;
        router.swapNFTsForToken(
            swapList,
            sellAmount,
            payable(address(this)),
            block.timestamp
        );
    }
}
