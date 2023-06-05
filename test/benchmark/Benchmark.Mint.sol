// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BenchmarkBase} from "test/benchmark/BenchmarkBase.sol";

contract BenchmarkMint is Test, BenchmarkBase {
    function testERC721EnumerableMint() external {
        erc721Enumerable.mint(address(this), 0);
    }

    function testERC721Mint() external {
        erc721.mint(address(this), 0);
    }

    function testERC721AMint() external {
        erc721A.mint(address(this), 1);
    }

    function testFrontPageERC721Mint() external {
        frontPageERC721.mint(address(this), 0);
    }
}
