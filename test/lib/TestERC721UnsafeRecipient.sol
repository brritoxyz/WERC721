// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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
