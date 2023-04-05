// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Snapshot} from "src/lib/ERC20Snapshot.sol";
import {ERC20} from "src/lib/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// contract Moon is ERC20("Moonbase Token", "MOON", 18), Owned, ReentrancyGuard {
contract Moon is ERC20Snapshot, Owned, ReentrancyGuard {
    // Factories deploy MoonBook contracts and enable them to mint MOON rewards
    // When factories are upgraded, they are set as the new factory
    // Old factories will no longer be able to call `addMinter`, effectively
    // decomissioning them (since they can no longer deploy books that mint MOON)
    address public factory;

    // Mapping of factory MoonBook minters - by having factory as a key, we can
    // prevent deprecated MoonBooks (e.g. MoonBooks deployed by deprecated factories)
    // from minting MOON rewards
    mapping(address factory => mapping(address minter => bool)) public minters;

    event SetFactory(address indexed factory);
    event AddMinter(address indexed factory, address indexed minter);

    error InvalidAddress();
    error NotFactory();
    error NotMinter();

    constructor(
        address _owner
    ) Owned(_owner) ERC20("Moonbase Token", "MOON", 18) {
        if (_owner == address(0)) revert InvalidAddress();
    }

    /**
     * @notice Set factory
     * @param  _factory  address  MoonBookFactory contract address
     */
    function setFactory(address _factory) external onlyOwner {
        if (_factory == address(0)) revert InvalidAddress();

        factory = _factory;

        emit SetFactory(_factory);
    }

    /**
     * @notice Add new minter
     * @param  minter  address  Minter address
     */
    function addMinter(address minter) external {
        if (msg.sender != factory) revert NotFactory();
        if (minter == address(0)) revert InvalidAddress();

        minters[factory][minter] = true;

        emit AddMinter(factory, minter);
    }

    /**
     * @notice Overridden _mint with the Transfer event emission removed (to reduce gas)
     * @param  to      address  Recipient address
     * @param  amount  uint256  Mint amount
     */
    function _mint(address to, uint256 amount) internal override {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }
    }

    /**
     * @notice Mint MOON
     * @param  to      address  Recipient address
     * @param  amount  uint256  Mint amount
     */
    function mint(address to, uint256 amount) external {
        if (!minters[factory][msg.sender]) revert NotMinter();

        _mint(to, amount);
    }

    /**
     * @notice Mint MOON for a buyer and seller pair
     * @param  buyer   address  Buyer address
     * @param  seller  address  Seller address
     * @param  amount  uint256  Mint amount
     */
    function mint(address buyer, address seller, uint256 amount) external {
        if (!minters[factory][msg.sender]) revert NotMinter();

        _mint(buyer, amount);
        _mint(seller, amount);
    }
}
