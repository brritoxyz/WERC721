// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IUserModule {
    function getWithdrawFee(uint256) external view returns (uint256);
}
