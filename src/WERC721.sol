// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clone} from "solady/utils/Clone.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "src/lib/ERC721TokenReceiver.sol";

contract WERC721 is Clone {
    // Immutable `collection` arg. Offset by 0 bytes since it's first.
    uint256 private constant IMMUTABLE_ARG_OFFSET_COLLECTION = 0;

    // Find the owner of an NFT.
    mapping(uint256 id => address owner) public ownerOf;

    // Query if an address is an authorized operator for another address.
    mapping(address owner => mapping(address operator => bool approved))
        public isApprovedForAll;

    // This emits when ownership of any NFT changes by any mechanism.
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    // This emits when an operator is enabled or disabled for an owner.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    error NotTokenOwner();
    error InvalidTokenId();
    error UnsafeTokenRecipient();
    error NotApprovedOperator();
    error NotAuthorizedCaller();

    /**
     * @notice The underlying ERC-721 collection contract.
     * @return ERC721  The underlying ERC-721 collection contract.
     */
    function collection() public pure returns (ERC721) {
        return ERC721(_getArgAddress(IMMUTABLE_ARG_OFFSET_COLLECTION));
    }

    /**
     * @notice The descriptive name for a collection of NFTs in this contract.
     * @dev    We are returning the value of `name()` on the underlying ERC-721
     *         contract for parity between the derivatives and the actual assets.
     * @return string  The descriptive name for a collection of NFTs in this contract.
     */
    function name() external view returns (string memory) {
        return collection().name();
    }

    /**
     * @notice An abbreviated name for NFTs in this contract.
     * @dev    We are returning the value of `symbol()` on the underlying ERC-721
     *         contract for parity between the derivatives and the actual assets.
     * @return string  An abbreviated name for NFTs in this contract.
     */
    function symbol() external view returns (string memory) {
        return collection().symbol();
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
     * @dev    We are returning the value of `tokenURI(id)` on the underlying ERC-721
     *         contract for parity between the derivatives and the actual assets.
     * @param  id  uint256  The identifier for an NFT.
     * @return     string   A valid URI for the asset.
     */
    function tokenURI(uint256 id) external view returns (string memory) {
        // Throws if `id` is not a valid NFT.
        if (ownerOf[id] == address(0)) revert InvalidTokenId();

        return collection().tokenURI(id);
    }

    /**
     * @notice Enable or disable approval for a third party ("operator") to manage all of `msg.sender`'s assets.
     * @param  operator  address  Address to add to the set of authorized operators.
     * @param  approved  bool     True if the operator is approved, false to revoke approval.
     */
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @notice Transfer ownership of an NFT.
     * @param  from  address  The current owner of the NFT.
     * @param  to    address  The new owner.
     * @param  id    uint256  The NFT to transfer.
     */
    function transferFrom(address from, address to, uint256 id) public payable {
        // Throws unless `msg.sender` is the current owner, or an authorized operator.
        if (msg.sender != from && !isApprovedForAll[from][msg.sender])
            revert NotApprovedOperator();

        // Throws if `from` is not the current owner or if `id` is not a valid NFT.
        if (from != ownerOf[id]) revert NotTokenOwner();

        // Throws if `to` is the zero address.
        if (to == address(0)) revert UnsafeTokenRecipient();

        // Set new owner as `to`.
        ownerOf[id] = to;

        emit Transfer(from, to, id);
    }

    /**
     * @notice Transfers the ownership of an NFT from one address to another address.
     * @param  from  address  The current owner of the NFT.
     * @param  to    address  The new owner.
     * @param  id    uint256  The NFT to transfer.
     * @param  data  bytes    Additional data with no specified format, sent in call to `to`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) external payable {
        transferFrom(from, to, id);

        // Throws if `to` is a smart contract and has an invalid `onERC721Received` return value.
        if (
            to.code.length != 0 &&
            ERC721TokenReceiver(to).onERC721Received(
                msg.sender,
                from,
                id,
                data
            ) !=
            ERC721TokenReceiver.onERC721Received.selector
        ) revert UnsafeTokenRecipient();
    }

    /**
     * @notice Transfers the ownership of an NFT from one address to another address.
     * @param  from  address  The current owner of the NFT.
     * @param  to    address  The new owner.
     * @param  id    uint256  The NFT to transfer.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external payable {
        transferFrom(from, to, id);

        // Throws if `to` is a smart contract and has an invalid `onERC721Received` return value.
        if (
            to.code.length != 0 &&
            ERC721TokenReceiver(to).onERC721Received(
                msg.sender,
                from,
                id,
                ""
            ) !=
            ERC721TokenReceiver.onERC721Received.selector
        ) revert UnsafeTokenRecipient();
    }

    /**
     * @notice Wrap an ERC-721 NFT.
     * @param  to  address  The owner of the wrapped ERC-721 NFT.
     * @param  id  uint256  The NFT to deposit and wrap.
     */
    function wrap(address to, uint256 id) external {
        // Transfer the ERC-721 NFT to this contract using `safeTransferFrom`, which will
        // result in the `onERC721Received` hook being called (contains minting logic).
        collection().safeTransferFrom(
            msg.sender,
            address(this),
            id,
            abi.encode(to)
        );
    }

    /**
     * @notice Unwrap an ERC-721 NFT.
     * @param  to  address  The owner of the unwrapped ERC-721 NFT.
     * @param  id  uint256  The NFT to unwrap and withdraw.
     */
    function unwrap(address to, uint256 id) external {
        // Throws if `msg.sender` is not the owner of the wrapped NFT.
        if (ownerOf[id] != msg.sender) revert NotTokenOwner();

        // Burn the wrapped NFT before transferring the ERC-721 NFT to the withdrawer.
        delete ownerOf[id];

        // Emit `Transfer` with zero address as the `to` member to denote a burn.
        emit Transfer(msg.sender, address(0), id);

        // Transfer the ERC-721 NFT to the recipient.
        collection().safeTransferFrom(address(this), to, id);
    }

    /**
     * @notice Wrap an ERC-721 NFT using a "safe" ERC-721 method (e.g. `safeTransferFrom` or `safeMint`).
     * @dev    It is the responsibility of the ERC-721 implementer to ensure that `onERC721Received` is
     *         implemented and works correctly.
     * @param  id    uint256  The NFT to deposit and wrap.
     * @param  data  bytes    Encoded recipient address.
     */
    function onERC721Received(
        address,
        address,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4) {
        // Throws if `msg.sender` is not the collection contract.
        if (msg.sender != address(collection())) revert NotAuthorizedCaller();

        // Decode the recipient of the wrapped ERC-721 NFT.
        address to = abi.decode(data, (address));

        // Mint the wrapped NFT for the depositor.
        ownerOf[id] = to;

        // Emit `Transfer` with zero address as the `from` member to denote a mint.
        emit Transfer(address(0), to, id);

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
