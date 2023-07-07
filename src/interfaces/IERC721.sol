// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC721 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 id) external view returns (string memory);

    function transferFrom(address from, address to, uint256 id) external;

    function safeTransferFrom(address from, address to, uint256 id) external;
}
