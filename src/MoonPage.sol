// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC1155, ERC1155TokenReceiver} from "src/base/MoonERC1155.sol";

contract MoonPage is
    Initializable,
    ReentrancyGuard,
    Owned,
    ERC721TokenReceiver,
    ERC1155
{
    ERC721 public collection;

    error Zero();
    error Invalid();

    constructor() Owned(msg.sender) {
        // Disable initialization on the implementation contract
        _disableInitializers();
    }

    /**
     * @notice Initializes the minimal proxy with an owner and collection contract
     * @param  _owner       address  Contract owner (has ability to set URI)
     * @param  _collection  ERC721   Collection contract
     */
    function initialize(
        address _owner,
        ERC721 _collection
    ) external initializer {
        owner = _owner;
        collection = _collection;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    /**
     * @notice Deposit a NFT into the vault and receive a redeemable derivative token
     * @param  id         uint256  Collection token ID
     * @param  recipient  address  Derivative token recipient
     */
    function deposit(uint256 id, address recipient) external nonReentrant {
        if (recipient == address(0)) revert Zero();

        // Transfer the NFT to self before minting the derivative token
        // Reverts if unapproved or if msg.sender does not have the token
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Mint the derivative token for the specified recipient
        // Reverts if the recipient is unsafe, emits TransferSingle
        _mint(recipient, id);
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id         uint256  Collection token ID
     * @param  recipient  address  Derivative token recipient
     */
    function withdraw(uint256 id, address recipient) external nonReentrant {
        if (recipient == address(0)) revert Zero();

        // Revert if msg.sender is not the owner of the derivative token
        if (ownerOf[id] != msg.sender) revert Invalid();

        // Burn the derivative token before transferring the NFT to the recipient
        _burn(msg.sender, id);

        // Transfer the NFT to the recipient
        collection.safeTransferFrom(address(this), recipient, id);
    }
}
