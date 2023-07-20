// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

/**
 * @title Authorized `transferFrom` with EIP-712 signatures.
 * @notice Allow others to call `transferFrom` on your behalf with a signature-based authorization.
 * @notice Based on EIP-3009: https://eips.ethereum.org/EIPS/eip-3009.
 * @author kp (ppmoon69.eth)
 */
contract TransferFromWithAuthorization {
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // keccak256("TransferFromWithAuthorization(address relayer,address from,address to,uint256 tokenId,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 public constant TRANSFER_FROM_WITH_AUTHORIZATION_TYPEHASH =
        0x0e3210998bc7d4519a993d9c986d16a1be38c22a169884883d35e6a2e9bff24d;

    // keccak256("CancelAuthorization(address authorizer,bytes32 nonce)")
    bytes32 public constant CANCEL_AUTHORIZATION_TYPEHASH =
        0x158b0a9edf7a828aad02f63cd515c68ef2f50ba807396f6d12842833a1597429;

    // Returns the state of an authorization.
    mapping(address authorizer => mapping(bytes32 nonce => bool state))
        public authorizationState;

    // This emits when an authorization is used.
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    // This emits when an authorization is canceled.
    event AuthorizationCanceled(
        address indexed authorizer,
        bytes32 indexed nonce
    );

    /**
     * @notice Compute the EIP-712 domain separator.
     * @param name     string   The name of the DApp or the protocol.
     * @param version  string   The current major version of the signing domain.
     * @return         bytes32  The EIP-712 domain separator.
     */
    function computeDomainSeparator(
        string memory name,
        string memory version
    ) public view returns (bytes32) {
        uint256 chainId;

        assembly {
            chainId := chainid()
        }

        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(name)),
                    keccak256(bytes(version)),
                    chainId,
                    address(this)
                )
            );
    }
}
