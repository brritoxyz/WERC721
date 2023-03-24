// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract MoonToken is Owned, ERC20("MoonBase", "MOON", 18) {
    address public router;
    mapping(address user => uint256 amount) public mintable;

    event SetRouter(address);
    event IncreaseMintable(address[], uint256);

    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidArray();

    constructor(address _owner) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
    }

    modifier onlyRouter() {
        if (msg.sender != router) revert Unauthorized();
        _;
    }

    /**
     * @notice Set the router address
     * @param _router  address  Router address
     */
    function setRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert InvalidAddress();

        router = _router;

        emit SetRouter(_router);
    }

    /**
     * @notice Increase the mintable MOON amount for users
     * @param users    address[]  User addresses
     * @param amounts  uint256[]  Mintable amounts for each user
     */
    function increaseMintable(
        address[] calldata users,
        uint256[] calldata amounts
    ) external onlyRouter {
        uint256 uLen = users.length;

        if (uLen == 0) revert InvalidArray();
        if (uLen != amounts.length) revert InvalidArray();

        // The router will most likely increase the mint amount for 2-3 users
        // Potential minters: buyer, pair owner, and collection owner (others TBD)
        for (uint256 i; i < uLen; ) {
            mintable[users[i]] += amounts[i];

            unchecked {
                ++i;
            }
        }

        emit IncreaseMintable(users, amount);
    }

    /**
     * @notice Mints MOON equal to msg.sender's mintable amount
     */
    function mint() external returns (uint256 amount) {
        amount = mintable[msg.sender];

        if (amount == 0) revert InvalidAmount();

        mintable[msg.sender] = 0;

        _mint(msg.sender, amount);
    }
}
