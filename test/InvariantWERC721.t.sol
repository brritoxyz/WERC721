// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {WERC721Factory} from "src/WERC721Factory.sol";
import {WERC721} from "src/WERC721.sol";
import {ERC721TokenReceiver} from "test/lib/ERC721TokenReceiver.sol";
import {TestERC721} from "test/lib/TestERC721.sol";
import {WERC721InvariantHandler} from "test/InvariantWERC721Handler.sol";
import {WERC721Helper} from "test/lib/WERC721Helper.sol";

contract InvariantWERC721Test is Test, WERC721Helper {
    TestERC721 public collection;
    WERC721Factory public factory;
    WERC721 public wrapper;
    WERC721InvariantHandler public handler;

    bytes4[] handlerSelectors = [
        WERC721InvariantHandler.wrap.selector,
        WERC721InvariantHandler.unwrap.selector
    ];

    function setUp() public {
        collection = new TestERC721();
        factory = new WERC721Factory();
        wrapper = WERC721(factory.create(address(collection)));
        handler = new WERC721InvariantHandler(collection, wrapper);

        // Target the handler and specific function selectors.
        targetSelector(FuzzSelector(address(handler), handlerSelectors));
        targetContract(address(handler));

        // Exclude the following contracts from being called.
        excludeContract(address(collection));
        excludeContract(address(factory));
        excludeContract(address(wrapper));
    }

    function invariantTokenOwnership() public {
        // Only perform the assertions below after 1 or more ERC721 tokens have been minted.
        if (handler.initialized()) {
            uint256 tokenId = handler.tokenId();

            if (address(0) != _getOwnerOf(address(wrapper), tokenId)) {
                // If a wrapper token exists, then the collection token must be owned by the wrapper.
                assertEq(address(wrapper), collection.ownerOf(tokenId));

                // The wrapper token owner should be the handler account (NOTE: consider fuzzing the recipient).
                assertEq(address(handler), wrapper.ownerOf(tokenId));
            } else {
                // If the wrapper token does not exist, then the collection token must be owned by the handler.
                assertEq(address(handler), collection.ownerOf(tokenId));
            }
        }
    }
}
