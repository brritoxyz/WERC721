// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

/// @notice Our non-standard ERC-721 contract is the result of extracting only the most essential
///         functionality from the ERC-721 and ERC-1155 standards. Based on Solmate implementations:
///         https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol
///         https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol
abstract contract PageERC721 {
    // Tracks the owner of each ERC721 derivative
    mapping(uint256 => address) public ownerOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    event TransferBatch(
        address indexed from,
        address indexed to,
        uint256[] ids
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function tokenURI(
        uint256 _tokenId
    ) external view virtual returns (string memory);

    function balanceOf(
        address owner,
        uint256 id
    ) external view returns (uint256) {
        return ownerOf[id] == owner ? 1 : 0;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 id) external {
        require(from == ownerOf[id], "WRONG_FROM");
        require(to != address(0), "UNSAFE_RECIPIENT");
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Set new owner as `to`
        ownerOf[id] = to;

        emit Transfer(from, to, id);
    }

    function batchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids
    ) external {
        require(to != address(0), "UNSAFE_RECIPIENT");
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            require(from == ownerOf[id], "WRONG_FROM");

            ownerOf[id] = to;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(from, to, ids);
    }

    function balanceOfBatch(
        address[] calldata owners,
        uint256[] calldata ids
    ) external view returns (uint256[] memory balances) {
        balances = new uint256[](owners.length);

        for (uint256 i; i < owners.length; ) {
            // Reverts with index OOB error if arrays are mismatched
            balances[i] = ownerOf[ids[i]] == owners[i] ? 1 : 0;

            unchecked {
                ++i;
            }
        }
    }
}
