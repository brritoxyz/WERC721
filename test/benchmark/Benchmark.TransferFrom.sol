// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BenchmarkBase} from "test/benchmark/BenchmarkBase.sol";

contract BenchmarkTransferFrom is Test, BenchmarkBase {
    address private constant TRANSFER_TO =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private constant TRANSFER_ID = 0;

    function testERC721EnumerableTransferFrom() external {
        erc721Enumerable.mint(address(this), TRANSFER_ID);
        erc721Enumerable.transferFrom(address(this), TRANSFER_TO, TRANSFER_ID);
    }

    function testERC721TransferFrom() external {
        erc721.mint(address(this), TRANSFER_ID);
        erc721.transferFrom(address(this), TRANSFER_TO, TRANSFER_ID);
    }

    function testERC721ATransferFrom() external {
        erc721A.mint(address(this), 1);
        erc721A.transferFrom(address(this), TRANSFER_TO, TRANSFER_ID);
    }

    function testFrontPageERC721TransferFrom() external {
        frontPageERC721.mint(address(this), TRANSFER_ID);
        frontPageERC721.transferFrom(address(this), TRANSFER_TO, TRANSFER_ID);
    }
}
