// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @notice This non-standard token contract is the result of extracting only the most essential
 *         functionality from the ERC-721 and ERC-1155 interfaces. Inspired by Solmate contracts:
 *         https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol
 *         https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol
 * @notice Dedicated to Jude 🐾
 * @author KP (https://github.com/kphed/jpage/blob/master/src/PageToken.sol)
 * @dev    The usual events are NOT emitted since this contract is intended to be maximally gas-efficient
 *         and interacted with by contracts. This decision was made to reduce user gas costs across all
 *         contract-based NFT marketplaces that integrate (those contracts can emit events if desired)
 */
contract PageToken {
    // Tracks the owner of each ERC721 derivative
    mapping(uint256 => address) public ownerOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    error WrongFrom();
    error UnsafeRecipient();
    error NotAuthorized();

    function balanceOf(
        address owner,
        uint256 id
    ) external view returns (uint256) {
        return ownerOf[id] == owner ? 1 : 0;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function transfer(address to, uint256 id) external {
        // Revert if `msg.sender` is not the token owner
        if (msg.sender != ownerOf[id]) revert WrongFrom();

        // Revert if `to` is the zero address
        if (to == address(0)) revert UnsafeRecipient();

        // Set new owner as `to`
        ownerOf[id] = to;
    }

    function batchTransfer(
        address[] calldata to,
        uint256[] calldata ids
    ) external {
        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            id = ids[i];

            // Revert if `msg.sender` is not the token owner
            if (msg.sender != ownerOf[id]) revert WrongFrom();

            // Revert if `to` is the zero address
            if (to[i] == address(0)) revert UnsafeRecipient();

            // Set new owner as `to`
            ownerOf[id] = to[i];

            unchecked {
                ++i;
            }
        }
    }

    function transferFrom(address from, address to, uint256 id) external {
        // Revert if `from` is not the token owner
        if (from != ownerOf[id]) revert WrongFrom();

        // Revert if `to` is the zero address
        if (to == address(0)) revert UnsafeRecipient();

        // Revert if `msg.sender` is not `from` and does not have transfer approval
        if (msg.sender != from && !isApprovedForAll[from][msg.sender])
            revert NotAuthorized();

        // Set new owner as `to`
        ownerOf[id] = to;
    }

    function batchTransferFrom(
        address from,
        address[] calldata to,
        uint256[] calldata ids
    ) external {
        // Revert if `msg.sender` is not `from` and does not have transfer approval
        if (msg.sender != from && !isApprovedForAll[from][msg.sender])
            revert NotAuthorized();

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            id = ids[i];

            // Revert if `from` is not the token owner
            if (from != ownerOf[id]) revert WrongFrom();

            // Revert if `to` is the zero address
            if (to[i] == address(0)) revert UnsafeRecipient();

            ownerOf[id] = to[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }

    function balanceOfBatch(
        address[] calldata owners,
        uint256[] calldata ids
    ) external view returns (uint256[] memory balances) {
        uint256 ownersLength = owners.length;
        balances = new uint256[](ownersLength);

        for (uint256 i = 0; i < ownersLength; ) {
            // Reverts with index OOB error if arrays are mismatched
            balances[i] = ownerOf[ids[i]] == owners[i] ? 1 : 0;

            unchecked {
                ++i;
            }
        }
    }
}
