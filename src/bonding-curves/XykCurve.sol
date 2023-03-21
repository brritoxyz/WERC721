// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {FixedPointMathLib} from "src/lib/FixedPointMathLib.sol";
import {ICurve} from "src/interfaces/ICurve.sol";
import {CurveErrorCodes} from "src/bonding-curves/CurveErrorCodes.sol";
import {Pair} from "src/sudoswap/Pair.sol";
import {PairCloner} from "src/lib/PairCloner.sol";
import {PairERC20} from "sudoswap/PairERC20.sol";
import {IPairFactoryLike} from "sudoswap/PairFactory.sol";

/*
    @author 0xacedia
    @notice Bonding curve logic for an x*y=k curve using virtual reserves.
    @dev    The virtual token reserve is stored in `spotPrice` and the virtual nft reserve is stored in `delta`.
            An LP can modify the virtual reserves by changing the `spotPrice` (tokens) or `delta` (nfts).
*/
contract XykCurve is ICurve, CurveErrorCodes {
    using FixedPointMathLib for uint256;

    /**
        @dev See {ICurve-validateDelta}
     */
    function validateDelta(uint128) external pure override returns (bool) {
        // all values are valid
        return true;
    }

    /**
        @dev See {ICurve-validateSpotPrice}
     */
    function validateSpotPrice(uint128) external pure override returns (bool) {
        // all values are valid
        return true;
    }

    /**
        @dev See {ICurve-getBuyInfo}
     */
    function getBuyInfo(
        uint128 spotPrice,
        uint128 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        pure
        override
        returns (
            Error error,
            uint128 newSpotPrice,
            uint128 newDelta,
            uint256 inputValue,
            uint256 protocolFee
        )
    {
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        // get the pair's virtual nft and eth/erc20 reserves
        uint256 tokenBalance = spotPrice;
        uint256 nftBalance = delta;

        // If numItems is too large, we will get divide by zero error
        if (numItems >= nftBalance) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        // calculate the amount to send in
        uint256 inputValueWithoutFee = (numItems * tokenBalance) /
            (nftBalance - numItems);

        // add the fees to the amount to send in
        protocolFee = inputValueWithoutFee.fmul(
            protocolFeeMultiplier,
            FixedPointMathLib.WAD
        );
        uint256 fee = inputValueWithoutFee.fmul(
            feeMultiplier,
            FixedPointMathLib.WAD
        );
        inputValue = inputValueWithoutFee + fee + protocolFee;

        // set the new virtual reserves
        newSpotPrice = uint128(spotPrice + inputValueWithoutFee); // token reserve
        newDelta = uint128(nftBalance - numItems); // nft reserve

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    /**
        @dev See {ICurve-getSellInfo}
     */
    function getSellInfo(
        uint128 spotPrice,
        uint128 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        pure
        override
        returns (
            Error error,
            uint128 newSpotPrice,
            uint128 newDelta,
            uint256 outputValue,
            uint256 protocolFee
        )
    {
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        // get the pair's virtual nft and eth/erc20 balance
        uint256 tokenBalance = spotPrice;
        uint256 nftBalance = delta;

        // calculate the amount to send out
        uint256 outputValueWithoutFee = (numItems * tokenBalance) /
            (nftBalance + numItems);

        // subtract fees from amount to send out
        protocolFee = outputValueWithoutFee.fmul(
            protocolFeeMultiplier,
            FixedPointMathLib.WAD
        );
        uint256 fee = outputValueWithoutFee.fmul(
            feeMultiplier,
            FixedPointMathLib.WAD
        );
        outputValue = outputValueWithoutFee - fee - protocolFee;

        // set the new virtual reserves
        newSpotPrice = uint128(spotPrice - outputValueWithoutFee); // token reserve
        newDelta = uint128(nftBalance + numItems); // nft reserve

        // If we got all the way here, no math error happened
        error = Error.OK;
    }
}
