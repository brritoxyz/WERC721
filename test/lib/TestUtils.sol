// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library TestUtils {
    function computeCreate2Address(
        address deployer,
        bytes32 salt,
        bytes calldata bytecode
    ) external pure returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                deployer,
                                salt,
                                keccak256(bytecode)
                            )
                        )
                    )
                )
            );
    }
}
