// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

/// @notice This non-standard (NS) ERC-1155 implementation deviates from the standard in exactly the following ways:
///         - `TransferSingle` and `TransferBatch` events are NOT emitted for mints and burns
///         - `TransferSingle` and `TransferBatch` events are NOT emitted outside of `safeTransferFrom` and `safeBatchTransferFrom`
///         - `onERC1155Received` and `onERC1155BatchReceived` are NOT called outside of `safeTransferFrom` and `safeBatchTransferFrom`
/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155NS {
    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private constant SINGLE_AMOUNT = 1;

    // Tracks the owner of each non-fungible derivative
    mapping(uint256 => address) public ownerOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function _balanceOf(
        address owner,
        uint256 id
    ) private view returns (uint256) {
        return ownerOf[id] == owner ? 1 : 0;
    }

    function balanceOf(
        address owner,
        uint256 id
    ) external view returns (uint256) {
        return _balanceOf(owner, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 id) public virtual {
        require(to != address(0), "UNSAFE_RECIPIENT");
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Verify that `from` owns the token prior to transfer
        require(ownerOf[id] == from, "NOT_AUTHORIZED");

        // Set new owner as `to`
        ownerOf[id] = to;
    }

    function batchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids
    ) public virtual {
        require(to != address(0), "UNSAFE_RECIPIENT");
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];

            require(ownerOf[id] == from, "NOT_AUTHORIZED");

            ownerOf[id] = to;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256,
        bytes calldata data
    ) public virtual {
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Verify that `from` owns the token prior to transfer
        require(ownerOf[id] == from, "NOT_AUTHORIZED");

        // Set new owner as `to`
        ownerOf[id] = to;

        emit TransferSingle(msg.sender, from, to, id, SINGLE_AMOUNT);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    from,
                    id,
                    SINGLE_AMOUNT,
                    data
                ) == ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata,
        bytes calldata data
    ) public virtual {
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256[] memory amounts = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amounts[i] = SINGLE_AMOUNT;

            require(ownerOf[id] == from, "NOT_AUTHORIZED");

            ownerOf[id] = to;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    msg.sender,
                    from,
                    ids,
                    amounts,
                    data
                ) == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOfBatch(
        address[] calldata owners,
        uint256[] calldata ids
    ) public view virtual returns (uint256[] memory balances) {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = _balanceOf(owners[i], ids[i]);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
