// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC1155, ERC1155TokenReceiver} from "src/base/MoonERC1155.sol";

contract MoonPage is Owned, ERC721TokenReceiver, ERC1155 {
    uint256 private constant ONE = 1;
    bytes private constant EMPTY_DATA = "";

    ERC721 public immutable collection;

    string private _uri = "";

    error Zero();
    error Invalid();

    constructor(ERC721 _collection) Owned(msg.sender) {
        if (address(_collection) == address(0)) revert Zero();

        collection = _collection;
    }

    /**
     * @notice Computes the ID of a derivative token
     * @param  id  uint256  Collection token ID
     * @return     uint256  Uint256-casted collection and ID hash
     */
    function _computeDerivativeId(uint256 id) internal view returns (uint256) {
        // Since we are dealing with unique collection contract addresses
        // and single quantity token IDs (ERC721 only), there won't be clashes
        return uint256(keccak256(abi.encodePacked(collection, id)));
    }

    function setURI(string memory newuri) external onlyOwner {
        _uri = newuri;

        // The value of `0` for `id` is a catchall since IDs will never be zero
        // See comment block below for more details on how to construct the token URI
        emit URI(newuri, 0);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view override returns (string memory) {
        return _uri;
    }

    /**
     * @notice Deposit a NFT into the vault and receive a derivative token
     * @param  id          uint256  Collection token ID
     * @param  recipient   address  Derivative token recipient
     */
    function deposit(uint256 id, address recipient) external {
        if (address(collection) == address(0)) revert Zero();
        if (recipient == address(0)) revert Zero();

        // Transfer NFT to self before minting the derivative token
        // Reverts if unapproved or if msg.sender does not have the token
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Mint the derivative token for the specified recipient
        // Reverts if the recipient is unsafe, emits TransferSingle
        _mint(recipient, _computeDerivativeId(id), ONE, EMPTY_DATA);
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id          uint256  Collection token ID
     * @param  recipient   address  Derivative token recipient
     */
    function withdraw(uint256 id, address recipient) external {
        if (address(collection) == address(0)) revert Zero();
        if (recipient == address(0)) revert Zero();

        uint256 derivativeId = _computeDerivativeId(id);

        // Revert if msg.sender is not the owner of the derivative token
        if (ownerOf[id] != msg.sender) revert Invalid();

        // Burn the derivative token before transferring the NFT to the recipient
        // The new owner is the burn address since it will be cheaper gas cost-wise
        _burn(msg.sender, derivativeId, ONE);

        // Transfer the NFT to the recipient
        collection.safeTransferFrom(address(this), recipient, id);
    }
}
