// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract EIP712 {
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

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
