// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

contract Moon is ERC20("Moonbase Token", "MOON", 18), Owned, ReentrancyGuard {
    mapping(address minter => bool) public minters;

    event AddMinter(address indexed minter);

    error InvalidAddress();
    error NotMinter();

    constructor(address _owner) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
    }

    /**
     * @notice Add new minter
     * @param  minter  address  Minter address
     */
    function addMinter(address minter) external onlyOwner {
        if (minter == address(0)) revert InvalidAddress();

        minters[minter] = true;

        emit AddMinter(minter);
    }

    /**
     * @notice Mint MOON
     * @param  to      address  Recipient address
     * @param  amount  uint256  Mint amount
     */
    function mint(address to, uint256 amount) external {
        if (!minters[msg.sender]) revert NotMinter();

        _mint(to, amount);
    }
}
