// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BenchmarkBase} from "test/benchmark/BenchmarkBase.sol";

contract BenchmarkBatchMint is Test, BenchmarkBase {
    // Number of NFTs to mint in a single call - modify to test gas for different quantities
    uint256 private constant BATCH_MINT_QTY = 10;

    function testERC721EnumerableBatchMint() external {
        erc721Enumerable.batchMint(address(this), BATCH_MINT_QTY);
    }

    function testERC721BatchMint() external {
        erc721.batchMint(address(this), BATCH_MINT_QTY);
    }

    function testERC721ABatchMint() external {
        erc721A.batchMint(address(this), BATCH_MINT_QTY);
    }

    function testFrontPageBatchMint() external {
        uint256[] memory ids = new uint256[](BATCH_MINT_QTY);

        for (uint256 i = 0; i < BATCH_MINT_QTY; ) {
            ids[i] = i;

            unchecked {
                ++i;
            }
        }

        frontPage.batchMint{value: BATCH_MINT_QTY * MINT_PRICE}(BATCH_MINT_QTY);
    }
}
