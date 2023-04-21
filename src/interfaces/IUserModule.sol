// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IUserModule {
    function deposit(uint256, address) external returns (uint256);

    function withdraw(uint256, address, address) external returns (uint256);

    function maxWithdraw(address) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function previewDeposit(uint256) external view returns (uint256);

    function convertToAssets(uint256) external view returns (uint256);

    function getWithdrawFee(uint256) external view returns (uint256);
}
