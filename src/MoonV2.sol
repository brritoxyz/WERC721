// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

interface IMoonStaker {
    function stakeETH() external payable returns (uint256, uint256);
}

contract Moon is Owned, ERC20("Redeemable Token", "MOON", 18), ReentrancyGuard {
    IMoonStaker public moonStaker;

    event SetMoonStaker(address indexed msgSender, IMoonStaker moonStaker);
    event StakeETH(
        address indexed msgSender,
        uint256 balance,
        uint256 assets,
        uint256 shares
    );
    event DepositETH(address indexed msgSender, uint256 msgValue);

    error InvalidAddress();
    error InvalidAmount();

    constructor() Owned(msg.sender) {}

    /**
     * @notice Set MoonStaker contract
     * @param  _moonStaker  MoonStaker  MoonStaker contract
     */
    function setMoonStaker(IMoonStaker _moonStaker) external onlyOwner {
        if (address(_moonStaker) == address(0)) revert InvalidAddress();

        moonStaker = _moonStaker;

        emit SetMoonStaker(msg.sender, _moonStaker);
    }

    /**
     * @notice Deposit ETH, receive MOON
     */
    function depositETH() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();

        // Mint MOON for msg.sender, equal to the ETH deposited
        _mint(msg.sender, msg.value);

        emit DepositETH(msg.sender, msg.value);
    }

    /**
     * @notice Stake ETH
     * @return balance  uint256  Contract ETH balance that is staked
     */
    function stakeETH() external nonReentrant returns (uint256 balance) {
        (uint256 assets, uint256 shares) = moonStaker.stakeETH{
            value: (balance = address(this).balance)
        }();

        emit StakeETH(msg.sender, balance, assets, shares);
    }
}
