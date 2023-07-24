// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Clone} from "solady/utils/Clone.sol";
import {Multicallable} from "solady/utils/Multicallable.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

/**
 * @title ERC721 wrapper contract.
 * @notice Wrap your ERC721 tokens for a redeemable derivative with:
 *         - Significantly less gas usage when transferring tokens;
 *         - Built-in call-batching (with multicall); and
 *         - Meta-transactions using EIP3009-inspired authorized transfers (ERC1271-compatible, thanks to Solady).
 * @author kp (ppmoon69.eth)
 * @custom:contributor vectorized.eth (vectorized.eth)
 */
contract WERC721 is Clone, Multicallable {
    // Immutable `collection` arg. Offset by 0 bytes since it's first.
    uint256 private constant IMMUTABLE_ARG_OFFSET_COLLECTION = 0;

    // EIP-712 domain typehash: keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)").
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // EIP-712 domain name (the user readable name of the signing domain): keccak256("WERC721").
    bytes32 private constant EIP712_DOMAIN_NAME =
        0x59b335d161aba1eac6f297a3046e2f74e6d4f8b1bc20b3766e382ce7e7b4369c;

    // EIP-712 domain version (the current major version of the signing domain): keccak256("1").
    bytes32 private constant EIP712_DOMAIN_VERSION =
        0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

    // Authorized transfer typehash: keccak256("TransferFromWithAuthorization(address relayer,address from,address to,uint256 tokenId,uint256 validAfter,uint256 validBefore,bytes32 nonce)").
    bytes32 private constant TRANSFER_FROM_WITH_AUTHORIZATION_TYPEHASH =
        0x0e3210998bc7d4519a993d9c986d16a1be38c22a169884883d35e6a2e9bff24d;

    // ERC165 interface identifier: bytes4(keccak256("supportsInterface(bytes4)")).
    bytes4 private constant ERC165_INTERFACE_ID = 0x01ffc9a7;

    // ERC721 ERC721TokenReceiver ERC165 interface identifier: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")).
    bytes4 private constant ERC165_INTERFACE_ID_ERC721_TOKEN_RECEIVER =
        0x150b7a02;

    // ERC721 ERC721Metadata ERC165 interface identifier: bytes4(keccak256("name()"))^bytes4(keccak256("symbol()"))^bytes4(keccak256("tokenURI(uint256)")).
    bytes4 private constant ERC165_INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    // Find the owner of an NFT.
    mapping(uint256 id => address owner) public ownerOf;

    // Query if an address is an authorized operator for another address.
    mapping(address owner => mapping(address operator => bool approved))
        public isApprovedForAll;

    // Returns the state of an authorization.
    mapping(address authorizer => mapping(bytes32 nonce => bool state))
        public authorizationState;

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

    // This emits when an authorization is used.
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    // This emits when an authorization is canceled.
    event AuthorizationCanceled(
        address indexed authorizer,
        bytes32 indexed nonce
    );

    error NotTokenOwner();
    error NotApprovedOperator();
    error NotAuthorizedCaller();
    error UnsafeTokenRecipient();
    error InvalidAuthorization();
    error AuthorizationAlreadyUsed();

    /**
     * @notice Get the EIP-712 domain separator.
     * @return bytes32  The EIP-712 domain separator.
     */
    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    EIP712_DOMAIN_NAME,
                    EIP712_DOMAIN_VERSION,
                    // Prevents the same signatures from being reused across different chains.
                    block.chainid,
                    // Prevents the same signatures from being reused across different WERC721 contracts.
                    address(this)
                )
            );
    }

    /**
     * @notice The underlying ERC721 collection contract.
     * @return ERC721  The underlying ERC721 collection contract.
     */
    function collection() public pure returns (ERC721) {
        return ERC721(_getArgAddress(IMMUTABLE_ARG_OFFSET_COLLECTION));
    }

    /**
     * @notice The descriptive name for a collection of NFTs in this contract.
     * @dev    We are returning the value of `name()` on the underlying ERC721
     *         contract for parity between the derivatives and the actual assets.
     * @return string  The descriptive name for a collection of NFTs in this contract.
     */
    function name() external view returns (string memory) {
        return collection().name();
    }

    /**
     * @notice An abbreviated name for NFTs in this contract.
     * @dev    We are returning the value of `symbol()` on the underlying ERC721
     *         contract for parity between the derivatives and the actual assets.
     * @return string  An abbreviated name for NFTs in this contract.
     */
    function symbol() external view returns (string memory) {
        return collection().symbol();
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
     * @dev    We are returning the value of `tokenURI(id)` on the underlying ERC721
     *         contract for parity between the derivatives and the actual assets.
     * @param  id  uint256  The identifier for an NFT.
     * @return     string   A valid URI for the asset.
     */
    function tokenURI(uint256 id) external view returns (string memory) {
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
    function transferFrom(address from, address to, uint256 id) external {
        // Throws unless `msg.sender` is the current owner, or an authorized operator.
        if (msg.sender != from && !isApprovedForAll[from][msg.sender])
            revert NotApprovedOperator();

        // Throws if `from` is not the owner.
        if (from != ownerOf[id]) revert NotTokenOwner();

        // Throws if `to` is the zero address.
        if (to == address(0)) revert UnsafeTokenRecipient();

        // Set new owner as `to`.
        ownerOf[id] = to;

        emit Transfer(from, to, id);
    }

    /**
     * @notice Transfer ownership of an NFT with an authorization.
     * @dev    Based on: https://eips.ethereum.org/EIPS/eip-3009.
     * @param  from         address  The current owner of the NFT and authorizer.
     * @param  to           address  The new owner.
     * @param  id           uint256  The NFT to transfer.
     * @param  validAfter   uint256  The time after which this is valid (unix time).
     * @param  validBefore  uint256  The time before which this is valid (unix time).
     * @param  nonce        bytes32  Unique nonce.
     * @param  v            uint8    Signature param.
     * @param  r            bytes32  Signature param.
     * @param  s            bytes32  Signature param.
     */
    function transferFromWithAuthorization(
        address from,
        address to,
        uint256 id,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Throws if `from` is not the owner.
        if (from != ownerOf[id]) revert NotTokenOwner();

        // Throws if `to` is the zero address.
        if (to == address(0)) revert UnsafeTokenRecipient();

        // Throws if `block.timestamp` is before `validAfter`.
        if (block.timestamp < validAfter) revert InvalidAuthorization();

        // Throws if `block.timestamp` is after `validBefore`.
        if (block.timestamp > validBefore) revert InvalidAuthorization();

        // Throws if `nonce` has already been used.
        if (authorizationState[from][nonce]) revert AuthorizationAlreadyUsed();

        // Set the nonce usage status to `true` to prevent reuse. This is called before
        // the signature is verified due to `SignatureCheckerLib` making an external call
        // if the signer is a contract account (staticcall but erring on the overly-safe
        // side and for the sake of consistency @ applying the CEI pattern).
        authorizationState[from][nonce] = true;

        emit AuthorizationUsed(from, nonce);

        // Set new owner as `to`.
        ownerOf[id] = to;

        emit Transfer(from, to, id);

        // Throws if the signature is invalid.
        if (
            !SignatureCheckerLib.isValidSignatureNow(
                from,
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        // Prevents collision with other contracts that may use the same structured data.
                        domainSeparator(),
                        keccak256(
                            abi.encode(
                                TRANSFER_FROM_WITH_AUTHORIZATION_TYPEHASH,
                                // `msg.sender` must match `relayer`, the account allowed to perform authorized transfers
                                // on behalf of `from`.
                                msg.sender,
                                from,
                                to,
                                id,
                                validAfter,
                                validBefore,
                                nonce
                            )
                        )
                    )
                ),
                v,
                r,
                s
            )
        ) revert InvalidAuthorization();
    }

    /**
     * @notice Cancel an authorization.
     * @param  nonce  bytes32  Unique nonce.
     */
    function cancelTransferFromAuthorization(bytes32 nonce) external {
        // Throws if `nonce` has already been used.
        if (authorizationState[msg.sender][nonce])
            revert AuthorizationAlreadyUsed();

        // Set the nonce usage status to `true` to prevent use by the relayer.
        authorizationState[msg.sender][nonce] = true;

        emit AuthorizationCanceled(msg.sender, nonce);
    }

    /**
     * @notice Wrap an ERC721 NFT.
     * @param  to  address  The recipient of the wrapped ERC721 NFT.
     * @param  id  uint256  The NFT to deposit and wrap.
     */
    function wrap(address to, uint256 id) external {
        // Throws if `to` is the zero address.
        if (to == address(0)) revert UnsafeTokenRecipient();

        // Mint the wrapped NFT for the depositor.
        ownerOf[id] = to;

        // Emit `Transfer` with zero address as the `from` member to denote a mint.
        emit Transfer(address(0), to, id);

        // Transfer the ERC721 NFT to this contract.
        collection().transferFrom(msg.sender, address(this), id);
    }

    /**
     * @notice Unwrap an ERC721 NFT.
     * @param  to  address  The recipient of the unwrapped ERC721 NFT.
     * @param  id  uint256  The NFT to unwrap and withdraw.
     */
    function unwrap(address to, uint256 id) external {
        // Throws if `msg.sender` is not the owner of the wrapped NFT.
        if (ownerOf[id] != msg.sender) revert NotTokenOwner();

        // Throws if `to` is the zero address.
        if (to == address(0)) revert UnsafeTokenRecipient();

        // Burn the wrapped NFT before transferring the ERC721 NFT to the specific recipient.
        delete ownerOf[id];

        // Emit `Transfer` with the zero address as the `to` member to denote a burn.
        emit Transfer(msg.sender, address(0), id);

        // Transfer the ERC721 NFT to the recipient.
        collection().transferFrom(address(this), to, id);
    }

    /**
     * @notice Wrap an ERC721 NFT using a "safe" ERC721 transfer method (e.g. `safeTransferFrom` or `safeMint`).
     * @dev    It is the responsibility of the ERC721 contract implement calls to `onERC721Received` correctly!
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

        // Decode the recipient of the wrapped ERC721 NFT. Will throw if `data` is an empty byte array.
        address to = abi.decode(data, (address));

        // Set the wrapped ERC721 owner as `to`.
        ownerOf[id] = to;

        // Emit `Transfer` with the zero address as the `from` member to denote a mint.
        emit Transfer(address(0), to, id);

        return this.onERC721Received.selector;
    }

    /**
     * @notice Query if a contract implements an interface
     * @param  interfaceID  bytes4  The interface identifier, as specified in ERC165.
     * @return              bool    Returns `true` if the contract implements `interfaceID`.
     */
    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return (interfaceID == ERC165_INTERFACE_ID ||
            interfaceID == ERC165_INTERFACE_ID_ERC721_TOKEN_RECEIVER ||
            interfaceID == ERC165_INTERFACE_ID_ERC721_METADATA);
    }
}
