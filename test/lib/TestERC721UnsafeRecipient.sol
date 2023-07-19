// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract TestERC721UnsafeRecipient {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return bytes4("");
    }
}
