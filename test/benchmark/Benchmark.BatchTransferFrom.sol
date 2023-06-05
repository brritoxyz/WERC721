// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BenchmarkBase} from "test/benchmark/BenchmarkBase.sol";

contract BenchmarkBatchTransferFrom is Test, BenchmarkBase {
    // Number of NFTs to mint in a single call - modify to test gas for different quantities
    uint256 private constant BATCH_QTY = 10;

    address[10] private transferTo = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
        0x976EA74026E726554dB657fA54763abd0C3a0aa9,
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,
        0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f,
        0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
    ];

    function _provisionTransferData(
        uint256 startId
    ) private view returns (address[] memory to, uint256[] memory ids) {
        to = new address[](BATCH_QTY);
        ids = new uint256[](BATCH_QTY);

        for (uint256 i = 0; i < BATCH_QTY; ) {
            to[i] = transferTo[i];
            ids[i] = startId + i;

            unchecked {
                ++i;
            }
        }
    }

    function testERC721EnumerableBatchTransferFrom() external {
        erc721Enumerable.batchMint(address(this), BATCH_QTY);

        (address[] memory to, uint256[] memory ids) = _provisionTransferData(0);

        erc721Enumerable.batchTransferFrom(address(this), to, ids);
    }

    function testERC721BatchTransferFrom() external {
        erc721.batchMint(address(this), BATCH_QTY);

        (address[] memory to, uint256[] memory ids) = _provisionTransferData(0);

        erc721.batchTransferFrom(address(this), to, ids);
    }

    function testERC721ABatchTransferFrom() external {
        erc721A.batchMint(address(this), BATCH_QTY);

        (address[] memory to, uint256[] memory ids) = _provisionTransferData(0);

        erc721A.batchTransferFrom(address(this), to, ids);
    }

    function testFrontPageBatchTransferFrom() external {
        uint256 id = frontPage.nextId();

        frontPage.batchMint{value: MINT_PRICE * BATCH_QTY}(BATCH_QTY);

        (address[] memory to, uint256[] memory ids) = _provisionTransferData(
            id
        );

        for (uint256 i = 0; i < BATCH_QTY; ) {
            assertEq(address(this), frontPage.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        frontPage.batchTransferFrom(address(this), to, ids);

        for (uint256 i = 0; i < BATCH_QTY; ) {
            assertEq(to[i], frontPage.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
