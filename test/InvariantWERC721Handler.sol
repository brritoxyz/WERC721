// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {WERC721} from "src/WERC721.sol";
import {ERC721TokenReceiver} from "test/lib/ERC721TokenReceiver.sol";
import {TestERC721} from "test/lib/TestERC721.sol";

contract WERC721InvariantHandler is ERC721TokenReceiver {
    TestERC721 public immutable collection;
    WERC721 public immutable wrapper;
    uint256 public tokenId;
    bool public initialized;

    constructor(TestERC721 _collection, WERC721 _wrapper) {
        collection = _collection;
        wrapper = _wrapper;

        collection.setApprovalForAll(address(wrapper), true);
    }

    function wrap(uint256 id) public {
        if (!initialized) initialized = true;

        // Used for checking token ownership.
        tokenId = id;

        // Mint the ERC721 token that is to be wrapped.
        collection.mint(address(this), id);

        // Wrap the ERC721 token.
        wrapper.wrap(address(this), id);
    }

    function unwrap(uint256 id) public {
        if (!initialized) initialized = true;

        tokenId = id;

        // Mint an ERC721 and wrap it.
        wrap(id);

        // Unwrap the WERC721 token.
        wrapper.unwrap(address(this), id);
    }
}
