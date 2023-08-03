// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";

contract WERC721Helper is Test {
    // Position of the `_ownerOf` mapping within the WERC721 contract.
    uint256 public constant STORAGE_SLOT_OWNER_OF = 0;

    // Position of the `authorizationState` mapping within the WERC721 contract.
    uint256 public constant STORAGE_SLOT_AUTHORIZATION_STATE = 2;

    /**
     * @notice Get the owner address for the token ID directly from the `_ownerOf` mapping.
     * @dev    Does not throw if owner is the zero address.
     * @param  id   uint256  The current owner of the NFT and authorizer.
     */
    function _getOwnerOf(
        address werc721,
        uint256 id
    ) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        vm.load(
                            werc721,
                            keccak256(abi.encode(id, STORAGE_SLOT_OWNER_OF))
                        )
                    )
                )
            );
    }

    /**
     * @notice Compute the storage location of `authorizationState[authorizer][nonce]`.
     * @param  from   address  The current owner of the NFT and authorizer.
     * @param  nonce  bytes32  Unique nonce.
     * @return        bytes32  Storage location.
     */
    function _getAuthorizationStateStorageLocation(
        address from,
        bytes32 nonce
    ) internal pure returns (bytes32) {
        return (
            // Storage location of `authorizationState[authorizer][nonce]`.
            // keccak256(nonceKey . keccak256(authorizerKey . mappingSlot)).
            keccak256(
                abi.encode(
                    nonce,
                    // Storage location of `authorizationState[authorizer]`.
                    // keccak256(authorizerKey . mappingSlot).
                    keccak256(
                        abi.encode(from, STORAGE_SLOT_AUTHORIZATION_STATE)
                    )
                )
            )
        );
    }
}
