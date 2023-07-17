// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract TestERC721SafeRecipient {
    // Enables us to verify whether the args were properly passed in the `onERC721Received` call.
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes memory _data
    ) public returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return this.onERC721Received.selector;
    }
}
