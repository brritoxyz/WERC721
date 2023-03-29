// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {LinearBase} from "test/moonbase/LinearBase.sol";
import {Pair} from "sudoswap/Pair.sol";
import {PairETH} from "sudoswap/PairETH.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {CurveErrorCodes} from "src/bonding-curves/CurveErrorCodes.sol";

contract PairEnumerableETHTest is ERC721TokenReceiver, LinearBase {
    using FixedPointMathLib for uint256;

    IERC721 private constant AZUKI =
        IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);
    address private constant AZUKI_OWNER =
        0x2aE6B0630EBb4D155C6e04fCB16840FFA77760AA;
    uint128 private constant DEFAULT_DELTA = 1 ether;
    uint96 private constant DEFAULT_FEE = 0.002e18;
    uint128 private constant DEFAULT_SPOT_PRICE = 1 ether;
    uint256 private constant PAIR_MAX_FEE = 0.90e18;

    PairETH private immutable pair;
    address private immutable pairAddr;

    // NFT IDs that are owned by the impersonated/pranked address
    uint256[] private initialNftIds = [0, 2, 7];

    event SpotPriceUpdate(uint128 newSpotPrice);
    event DeltaUpdate(uint128 newDelta);
    event FeeUpdate(uint96 newFee);
    event NFTWithdrawal();
    event SwapNFTOutPair();

    error Ownable_NotOwner();

    constructor() {
        vm.startPrank(AZUKI_OWNER);

        uint256 iLen = initialNftIds.length;

        // Transfer NFTs from owner to self
        for (uint256 i; i < iLen; ) {
            uint256 id = initialNftIds[i];

            assertTrue(AZUKI.ownerOf(id) == AZUKI_OWNER);

            AZUKI.safeTransferFrom(AZUKI_OWNER, address(this), id);

            assertTrue(AZUKI.ownerOf(id) == address(this));

            unchecked {
                ++i;
            }
        }

        vm.stopPrank();

        AZUKI.setApprovalForAll(address(factory), true);

        pair = factory.createPairETH(
            // IERC721 _nft,
            AZUKI,
            // ICurve _bondingCurve,
            linearCurve,
            // address payable _assetRecipient,
            payable(address(0)),
            // Pair.PoolType _poolType,
            Pair.PoolType.TRADE,
            // uint128 _delta,
            DEFAULT_DELTA,
            // uint96 _fee,
            DEFAULT_FEE,
            // uint128 _spotPrice,
            DEFAULT_SPOT_PRICE,
            // uint256[] calldata _initialNFTIDs
            initialNftIds
        );
        pairAddr = address(pair);

        // Verify that the pair contract has custody of the NFTs
        for (uint256 i; i < iLen; ) {
            uint256 id = initialNftIds[i];

            assertTrue(AZUKI.ownerOf(id) == pairAddr);

            unchecked {
                ++i;
            }
        }
    }

    function _getSwapInputValue(
        uint256 numItems
    ) internal view returns (uint256 inputValue) {
        (, , , inputValue, ) = linearCurve.getBuyInfo(
            pair.spotPrice(),
            pair.delta(),
            numItems,
            pair.fee(),
            factory.protocolFeeMultiplier()
        );
    }

    function _calculateLinearCurveBuyInfo(
        uint256 numNfts
    )
        internal
        view
        returns (
            uint256 price,
            uint256 fee,
            uint256 protocolFee,
            uint256 pairMintable,
            uint256 buyerMintable
        )
    {
        uint256 spotPrice = pair.spotPrice();
        uint256 delta = pair.delta();
        uint256 feeMultiplier = pair.fee();
        uint256 protocolFeeMultiplier = factory.protocolFeeMultiplier();

        price =
            numNfts *
            (spotPrice + delta) +
            (numNfts * (numNfts - 1) * delta) /
            2;
        fee = feeMultiplier.mulDivDown(price, 1e18);
        protocolFee = protocolFeeMultiplier.mulDivDown(price, 1e18);
        pairMintable = feeMultiplier >= protocolFeeMultiplier
            ? 0
            : protocolFee - fee;
        buyerMintable = protocolFee;
    }

    /*///////////////////////////////////////////////////////////////
                            changeSpotPrice
    //////////////////////////////////////////////////////////////*/

    function testCannotChangeSpotPriceNotOwner() external {
        uint128 newSpotPrice = pair.spotPrice() * 2;

        vm.prank(address(0));
        vm.expectRevert(Ownable_NotOwner.selector);

        pair.changeSpotPrice(newSpotPrice);
    }

    function testChangeSpotPrice() external {
        assertEq(address(this), pair.owner());

        uint128 newSpotPrice = DEFAULT_SPOT_PRICE * 2;

        emit SpotPriceUpdate(newSpotPrice);

        pair.changeSpotPrice(newSpotPrice);

        assertEq(newSpotPrice, pair.spotPrice());
    }

    function testChangeSpotPriceFuzz(uint128 newSpotPrice) external {
        vm.assume(newSpotPrice != DEFAULT_SPOT_PRICE);

        assertEq(address(this), pair.owner());

        emit SpotPriceUpdate(newSpotPrice);

        pair.changeSpotPrice(newSpotPrice);

        assertEq(newSpotPrice, pair.spotPrice());
    }

    /*///////////////////////////////////////////////////////////////
                            changeDelta
    //////////////////////////////////////////////////////////////*/

    function testCannotChangeDeltaNotOwner() external {
        uint128 newDelta = pair.delta() * 2;

        vm.prank(address(0));
        vm.expectRevert(Ownable_NotOwner.selector);

        pair.changeDelta(newDelta);
    }

    function testChangeDelta() external {
        assertEq(address(this), pair.owner());

        uint128 newDelta = DEFAULT_DELTA * 2;

        emit DeltaUpdate(newDelta);

        pair.changeDelta(newDelta);

        assertEq(newDelta, pair.delta());
    }

    function testChangeDeltaFuzz(uint128 newDelta) external {
        vm.assume(newDelta != DEFAULT_DELTA);

        assertEq(address(this), pair.owner());

        emit DeltaUpdate(newDelta);

        pair.changeDelta(newDelta);

        assertEq(newDelta, pair.delta());
    }

    /*///////////////////////////////////////////////////////////////
                                changeFee
    //////////////////////////////////////////////////////////////*/

    function testCannotChangeFeeNotOwner() external {
        uint96 newFee = pair.fee() * 2;

        vm.prank(address(0));
        vm.expectRevert(Ownable_NotOwner.selector);

        pair.changeFee(newFee);
    }

    function testChangeFee() external {
        assertEq(address(this), pair.owner());

        uint96 newFee = DEFAULT_FEE * 2;

        emit FeeUpdate(newFee);

        pair.changeFee(newFee);

        assertEq(newFee, pair.fee());
    }

    function testChangeFeeFuzz(uint96 newFee) external {
        vm.assume(newFee != DEFAULT_FEE);
        vm.assume(newFee < PAIR_MAX_FEE);

        assertEq(address(this), pair.owner());

        emit FeeUpdate(newFee);

        pair.changeFee(newFee);

        assertEq(newFee, pair.fee());
    }

    /*///////////////////////////////////////////////////////////////
                            withdrawERC721
    //////////////////////////////////////////////////////////////*/

    function testWithdrawERC721() external {
        uint256[] memory heldIds = pair.getAllHeldIds();
        IERC721 a = AZUKI;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = heldIds[0];

        assertTrue(AZUKI.ownerOf(nftIds[0]) == pairAddr);
        assertTrue(pair.owner() == address(this));

        vm.expectEmit(false, false, false, false, pairAddr);

        emit NFTWithdrawal();

        pair.withdrawERC721(a, nftIds);

        assertTrue(AZUKI.ownerOf(nftIds[0]) == address(this));

        uint256[] memory postWithdrawalHeldIds = pair.getAllHeldIds();

        assertEq(heldIds[1], postWithdrawalHeldIds[0]);
        assertEq(heldIds[2], postWithdrawalHeldIds[1]);
        assertEq(heldIds.length - 1, postWithdrawalHeldIds.length);
    }

    /*///////////////////////////////////////////////////////////////
                        swapTokenForAnyNFTs
    //////////////////////////////////////////////////////////////*/

    function testSwapTokenForAnyNFTs() external {
        uint256 numNfts = 1;
        uint256 maxExpectedTokenInput = _getSwapInputValue(numNfts);
        address nftRecipient = address(this);
        bool isRouter = false;
        address routerCaller = address(0);
        uint256 balanceBeforeSwap = address(this).balance;
        (
            uint256 price,
            uint256 fee,
            uint256 protocolFee,
            uint256 pairMintable,
            uint256 buyerMintable
        ) = _calculateLinearCurveBuyInfo(numNfts);

        assertEq(0, AZUKI.balanceOf(nftRecipient));

        vm.expectEmit(false, false, false, true, pairAddr);

        emit SwapNFTOutPair();

        uint256 inputAmount = pair.swapTokenForAnyNFTs{
            value: maxExpectedTokenInput
        }(numNfts, maxExpectedTokenInput, nftRecipient, isRouter, routerCaller);

        assertEq(numNfts, AZUKI.balanceOf(nftRecipient));
        assertEq(
            balanceBeforeSwap - maxExpectedTokenInput,
            address(this).balance
        );
        assertEq(inputAmount, maxExpectedTokenInput);
        assertEq(price + fee + protocolFee, inputAmount);
        assertEq(pairMintable, moon.mintable(pairAddr));
        assertEq(buyerMintable, moon.mintable(nftRecipient));
    }

    function testSwapTokenForAnyNFTsFuzz(
        uint8 numNfts,
        uint56 pairFeeMultiplier,
        uint56 protocolFeeMultiplier
    ) external {
        vm.assume(numNfts != 0);
        vm.assume(numNfts < AZUKI.balanceOf(pairAddr));
        vm.assume(pairFeeMultiplier <= 0.005e18);
        vm.assume(protocolFeeMultiplier != 0);
        vm.assume(protocolFeeMultiplier <= 0.005e18);

        // Fuzz fee multiplier percentages
        pair.changeFee(pairFeeMultiplier);
        factory.changeProtocolFeeMultiplier(protocolFeeMultiplier);

        uint256 maxExpectedTokenInput = _getSwapInputValue(numNfts);
        address nftRecipient = address(this);
        uint256 balanceBeforeSwap = address(this).balance;
        (
            uint256 price,
            uint256 fee,
            uint256 protocolFee,
            uint256 pairMintable,
            uint256 buyerMintable
        ) = _calculateLinearCurveBuyInfo(numNfts);

        assertEq(0, AZUKI.balanceOf(nftRecipient));

        vm.expectEmit(false, false, false, true, pairAddr);

        emit SwapNFTOutPair();

        uint256 inputAmount = pair.swapTokenForAnyNFTs{
            value: maxExpectedTokenInput
        }(numNfts, maxExpectedTokenInput, nftRecipient, false, address(0));

        assertEq(numNfts, AZUKI.balanceOf(nftRecipient));
        assertEq(
            balanceBeforeSwap - maxExpectedTokenInput,
            address(this).balance
        );
        assertEq(inputAmount, maxExpectedTokenInput);
        assertEq(price + fee + protocolFee, inputAmount);
        assertEq(pairMintable, moon.mintable(pairAddr));
        assertEq(buyerMintable, moon.mintable(nftRecipient));
    }

    /*///////////////////////////////////////////////////////////////
                        swapTokenForSpecificNFTs
    //////////////////////////////////////////////////////////////*/

    function testSwapTokenForSpecificNFTs() external {
        uint256 numNfts = 1;
        uint256[] memory nftIds = new uint256[](numNfts);
        nftIds[0] = initialNftIds[0];

        uint256 maxExpectedTokenInput = _getSwapInputValue(numNfts);
        address nftRecipient = address(this);
        bool isRouter = false;
        address routerCaller = address(0);
        uint256 balanceBeforeSwap = address(this).balance;
        (
            uint256 price,
            uint256 fee,
            uint256 protocolFee,
            uint256 pairMintable,
            uint256 buyerMintable
        ) = _calculateLinearCurveBuyInfo(numNfts);

        vm.expectEmit(false, false, false, true, pairAddr);

        emit SwapNFTOutPair();

        uint256 inputAmount = pair.swapTokenForSpecificNFTs{
            value: maxExpectedTokenInput
        }(nftIds, maxExpectedTokenInput, nftRecipient, isRouter, routerCaller);

        assertEq(nftRecipient, AZUKI.ownerOf(nftIds[0]));
        assertEq(
            balanceBeforeSwap - maxExpectedTokenInput,
            address(this).balance
        );
        assertEq(inputAmount, maxExpectedTokenInput);
        assertEq(price + fee + protocolFee, inputAmount);
        assertEq(pairMintable, moon.mintable(pairAddr));
        assertEq(buyerMintable, moon.mintable(nftRecipient));
    }

    function testSwapTokenForSpecificNFTsFuzz(uint8 addNftRand) external {
        uint256 numNfts = 1 + (addNftRand % 2 == 0 ? 1 : 2);
        uint256[] memory nftIds = new uint256[](numNfts);

        for (uint256 i; i < numNfts; ) {
            nftIds[i] = initialNftIds[i];

            unchecked {
                ++i;
            }
        }

        uint256 maxExpectedTokenInput = _getSwapInputValue(numNfts);
        address nftRecipient = address(this);
        uint256 balanceBeforeSwap = address(this).balance;
        (
            uint256 price,
            uint256 fee,
            uint256 protocolFee,
            uint256 pairMintable,
            uint256 buyerMintable
        ) = _calculateLinearCurveBuyInfo(numNfts);

        vm.expectEmit(false, false, false, true, pairAddr);

        emit SwapNFTOutPair();

        uint256 inputAmount = pair.swapTokenForSpecificNFTs{
            value: maxExpectedTokenInput
        }(nftIds, maxExpectedTokenInput, nftRecipient, false, address(0));

        for (uint256 i; i < numNfts; ) {
            assertEq(nftRecipient, AZUKI.ownerOf(nftIds[i]));

            unchecked {
                ++i;
            }
        }

        assertEq(
            balanceBeforeSwap - maxExpectedTokenInput,
            address(this).balance
        );
        assertEq(inputAmount, maxExpectedTokenInput);
        assertEq(price + fee + protocolFee, inputAmount);
        assertEq(pairMintable, moon.mintable(pairAddr));
        assertEq(buyerMintable, moon.mintable(nftRecipient));
    }
}
