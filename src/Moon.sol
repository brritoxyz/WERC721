// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract Moon is Owned, ERC20("MoonBase", "MOON", 18) {
    address public factory;

    // Factory-deployed pair addresses that can increase MOON mint amounts
    mapping(address minter => bool canMint) public minters;

    // User addresses and their mintable MOON amounts
    mapping(address user => uint256 amount) public mintable;

    event SetFactory(address);
    event AddMinter(address);
    event IncreaseMintable(
        address indexed buyer,
        address indexed pair,
        uint256 buyerAmount,
        uint256 pairAmount
    );

    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidArray();

    constructor(address _owner) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
    }

    /**
     * @notice Set the factory address
     * @param _factory  address  Factory address
     */
    function setFactory(address _factory) external onlyOwner {
        if (_factory == address(0)) revert InvalidAddress();

        factory = _factory;

        emit SetFactory(_factory);
    }

    /**
     * @notice Enables the factory to add a MOON minter (i.e. pair contract)
     * @param _minter  address  Minter address
     */
    function addMinter(address _minter) external {
        if (msg.sender != factory) revert Unauthorized();
        if (_minter == address(0)) revert InvalidAddress();

        minters[_minter] = true;

        emit AddMinter(_minter);
    }

    /**
     * @notice Enables a pair to increase the mintable MOON for a buyer and itself
     * @param buyer         address  Buyer address
     * @param buyerAmount   uint256  Buyer mintable amount
     * @param pairAmount    uint256  Pair mintable amount
     */
    function increaseMintable(
        address buyer,
        uint256 buyerAmount,
        uint256 pairAmount
    ) external {
        if (!minters[msg.sender]) revert Unauthorized();

        mintable[buyer] += buyerAmount;

        // pairAmount will be 0 if the pair fee is >= protocol fee
        if (pairAmount != 0) mintable[msg.sender] += pairAmount;

        emit IncreaseMintable(buyer, msg.sender, buyerAmount, pairAmount);
    }

    /**
     * @notice Mints MOON equal to msg.sender's mintable amount
     * @return amount  uint256  Minted amount
     */
    function mint() external returns (uint256 amount) {
        amount = mintable[msg.sender];

        if (amount == 0) revert InvalidAmount();

        mintable[msg.sender] = 0;

        _mint(msg.sender, amount);
    }
}
