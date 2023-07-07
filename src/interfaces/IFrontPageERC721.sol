// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IFrontPageERC721 {
    function mint(address to, uint256 id) external payable;

    function batchMint(address to, uint256[] calldata ids) external payable;
}
