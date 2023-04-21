// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ILido {
    function getSharesByPooledEth(uint256) external view returns (uint256);

    function getPooledEthByShares(uint256) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}
