// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {PairETH} from "sudoswap/PairETH.sol";
import {PairEnumerable} from "sudoswap/PairEnumerable.sol";
import {IPairFactoryLike} from "src/interfaces/IPairFactoryLike.sol";
import {ICurve} from "src/interfaces/ICurve.sol";
import {Moon} from "src/Moon.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is ETH
    @author boredGenius and 0xmons
 */
contract PairEnumerableETH is PairEnumerable, PairETH {
    using FixedPointMathLib for uint256;

    Moon public moon;

    event SetMoon(Moon);

    error Unauthorized();
    error InvalidAddress();

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

    /**
     * @notice Calculates and increases the mintable MOON amount for the buyer and pair
     * @param maxAmount               uint256  Max MOON mint amount (i.e. ETH taken as protocol fees)
     * @param protocolFeeMultiplier   uint256  Protocol fee multiplier percent
     * @param nftRecipient            address  NFT recipient (i.e. buyer)
     */
    function _calculateAndIncreaseMintableMoon(
        uint256 maxAmount,
        uint256 protocolFeeMultiplier,
        address nftRecipient
    ) private {
        uint256 pairMintAmount;

        // If the fee is less than the protocol fee, calculate the MOON amount after
        // deducting the amount received by the pair as fees (see more details below)
        if (fee < protocolFeeMultiplier) {
            // Lower pair fees results in a higher MOON mint amount for the pair
            // The maximum amount of MOON is minted if the pair fee is zero
            pairMintAmount =
                maxAmount -
                maxAmount.mulDivUp(fee, protocolFeeMultiplier);
        }

        // Increase the mintable MOON amount for the NFT recipient/buyer and the pair
        // The buyer always receives the maximum mintable MOON amount, since they are
        // the party paying fees
        moon.increaseMintable(nftRecipient, maxAmount, pairMintAmount);
    }

    /**
     * @notice Enables the factory to set the MOON protocol token
     * @dev    Separate method instead of constructor to minimize test changes
     * @param  _moon  Moon  MOON token contract
     */
    function setMoon(Moon _moon) external {
        // Only the factory can call this method (called during initialization)
        if (msg.sender != address(factory())) revert Unauthorized();

        moon = _moon;

        emit SetMoon(_moon);
    }

    function swapTokenForAnyNFTs(
        uint256 numNFTs,
        uint256 maxExpectedTokenInput,
        address nftRecipient,
        bool isRouter,
        address routerCaller
    ) external payable override nonReentrant returns (uint256 inputAmount) {
        // Store locally to remove extra calls
        IPairFactoryLike _factory = factory();
        ICurve _bondingCurve = bondingCurve();
        IERC721 _nft = nft();

        // Input validation
        {
            PoolType _poolType = poolType();
            require(
                _poolType == PoolType.NFT || _poolType == PoolType.TRADE,
                "Wrong Pool type"
            );
            require(
                (numNFTs > 0) && (numNFTs <= _nft.balanceOf(address(this))),
                "Ask for > 0 and <= balanceOf NFTs"
            );
        }

        // Call bonding curve for pricing information
        uint256 protocolFee;

        (protocolFee, inputAmount) = _calculateBuyInfoAndUpdatePoolParams(
            numNFTs,
            maxExpectedTokenInput,
            _bondingCurve,
            _factory
        );

        _pullTokenInputAndPayProtocolFee(
            inputAmount,
            isRouter,
            routerCaller,
            _factory,
            protocolFee
        );

        _sendAnyNFTsToRecipient(_nft, nftRecipient, numNFTs);

        _refundTokenToSender(inputAmount);

        if (protocolFee != 0) {
            // Calculate and increase the mintable MOON mint amounts for the buyer and seller
            _calculateAndIncreaseMintableMoon(
                protocolFee,
                _factory.protocolFeeMultiplier(),
                nftRecipient
            );
        }

        emit SwapNFTOutPair();
    }

    function swapTokenForSpecificNFTs(
        uint256[] calldata nftIds,
        uint256 maxExpectedTokenInput,
        address nftRecipient,
        bool isRouter,
        address routerCaller
    ) external payable override nonReentrant returns (uint256 inputAmount) {
        // Store locally to remove extra calls
        IPairFactoryLike _factory = factory();
        ICurve _bondingCurve = bondingCurve();

        // Input validation
        {
            PoolType _poolType = poolType();
            require(
                _poolType == PoolType.NFT || _poolType == PoolType.TRADE,
                "Wrong Pool type"
            );
            require((nftIds.length > 0), "Must ask for > 0 NFTs");
        }

        // Call bonding curve for pricing information
        uint256 protocolFee;

        (protocolFee, inputAmount) = _calculateBuyInfoAndUpdatePoolParams(
            nftIds.length,
            maxExpectedTokenInput,
            _bondingCurve,
            _factory
        );

        _pullTokenInputAndPayProtocolFee(
            inputAmount,
            isRouter,
            routerCaller,
            _factory,
            protocolFee
        );

        _sendSpecificNFTsToRecipient(nft(), nftRecipient, nftIds);

        _refundTokenToSender(inputAmount);

        if (protocolFee != 0) {
            _calculateAndIncreaseMintableMoon(
                protocolFee,
                _factory.protocolFeeMultiplier(),
                nftRecipient
            );
        }

        emit SwapNFTOutPair();
    }

    function swapNFTsForToken(
        uint256[] calldata nftIds,
        uint256 minExpectedTokenOutput,
        address payable tokenRecipient,
        bool isRouter,
        address routerCaller
    ) external override nonReentrant returns (uint256 outputAmount) {
        // Store locally to remove extra calls
        IPairFactoryLike _factory = factory();
        ICurve _bondingCurve = bondingCurve();

        // Input validation
        {
            PoolType _poolType = poolType();
            require(
                _poolType == PoolType.TOKEN || _poolType == PoolType.TRADE,
                "Wrong Pool type"
            );
            require(nftIds.length > 0, "Must ask for > 0 NFTs");
        }

        // Call bonding curve for pricing information
        uint256 protocolFee;

        (protocolFee, outputAmount) = _calculateSellInfoAndUpdatePoolParams(
            nftIds.length,
            minExpectedTokenOutput,
            _bondingCurve,
            _factory
        );

        _sendTokenOutput(tokenRecipient, outputAmount);

        _payProtocolFeeFromPair(_factory, protocolFee);

        _takeNFTsFromSender(nft(), nftIds, _factory, isRouter, routerCaller);

        if (protocolFee != 0) {
            _calculateAndIncreaseMintableMoon(
                protocolFee,
                _factory.protocolFeeMultiplier(),
                tokenRecipient
            );
        }

        emit SwapNFTInPair();
    }
}
