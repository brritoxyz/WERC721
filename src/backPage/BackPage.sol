// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clone} from "solady/utils/Clone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {PageExchange} from "src/PageExchange.sol";
import {PageERC721} from "src/PageERC721.sol";
import {IERC721} from "src/interfaces/IERC721.sol";

contract BackPage is Clone, PageERC721, PageExchange {
    using SafeTransferLib for address payable;

    // Fixed clone immutable arg byte offsets
    uint256 private constant IMMUTABLE_ARG_OFFSET_COLLECTION = 0;

    bool private _initialized;

    error AlreadyInitialized();

    constructor() payable {
        // Prevent the implementation from being initialized
        _initialized = true;
    }

    /**
     * @notice Initializes the minimal proxy contract storage
     */
    function initialize() external {
        if (_initialized) revert AlreadyInitialized();

        // Prevent initialize from being called again
        _initialized = true;

        // Initialize `locked` with the value of 1 (i.e. unlocked)
        locked = 1;
    }

    function collection() public pure override returns (address) {
        return _getArgAddress(IMMUTABLE_ARG_OFFSET_COLLECTION);
    }

    /**
     * @notice Deposit a NFT into the vault to mint a redeemable derivative token with the same ID
     * @param  id         uint256  Token ID
     * @param  recipient  address  Derivative token recipient
     */
    function _deposit(uint256 id, address recipient) private {
        // Mint the derivative token for the specified recipient (same ID)
        ownerOf[id] = recipient;

        // Transfer the NFT to self before minting the derivative token
        // Reverts if unapproved or if msg.sender does not have the token
        IERC721(collection()).transferFrom(msg.sender, address(this), id);
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id         uint256  Token ID
     * @param  recipient  address  NFT recipient
     */
    function _withdraw(uint256 id, address recipient) private {
        // Revert if msg.sender is not the owner of the derivative token
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Burn the derivative token before transferring the NFT to the recipient
        delete ownerOf[id];

        // Transfer the NFT to the recipient - reverts if recipient is zero address
        IERC721(collection()).safeTransferFrom(
            address(this),
            recipient,
            id
        );
    }

    /**
     * @notice Deposit a NFT into the vault to mint a redeemable derivative token with the same ID
     * @param  id         uint256  Token ID
     * @param  recipient  address  Derivative token recipient
     */
    function deposit(uint256 id, address recipient) external {
        _deposit(id, recipient);
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id         uint256  Token ID
     * @param  recipient  address  NFT recipient
     */
    function withdraw(uint256 id, address recipient) external {
        _withdraw(id, recipient);
    }

    /**
     * @notice Batch deposit
     * @param  ids        uint256[]  Token IDs
     * @param  recipient  address    Derivative token recipient
     */
    function batchDeposit(
        uint256[] calldata ids,
        address recipient
    ) external nonReentrant {
        uint256 idsLength = ids.length;

        // If ids.length is zero then the loop body never runs and caller wastes gas
        for (uint256 i = 0; i < idsLength; ) {
            _deposit(ids[i], recipient);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Batch withdraw
     * @param  ids        uint256[]  Token IDs
     * @param  recipient  address    NFT recipient
     */
    function batchWithdraw(
        uint256[] calldata ids,
        address recipient
    ) external nonReentrant {
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            _withdraw(ids[i], recipient);

            unchecked {
                ++i;
            }
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
