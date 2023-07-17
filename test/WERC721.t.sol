// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {TestERC721} from "test/lib/TestERC721.sol";
import {WERC721Factory} from "src/WERC721Factory.sol";
import {WERC721} from "src/WERC721.sol";

contract WERC721Test is Test, ERC721TokenReceiver {
    TestERC721 public immutable collection;
    WERC721Factory private immutable factory;
    WERC721 private immutable wrapperImplementation;
    WERC721 private immutable wrapper;

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

    constructor() {
        collection = new TestERC721();
        factory = new WERC721Factory();
        wrapperImplementation = factory.implementation();
        wrapper = WERC721(factory.create(collection));

        assertTrue(address(wrapperImplementation) != address(0));
        assertTrue(address(wrapper) != address(0));

        // Implementation should not have `collection` set.
        assertEq(address(0), address(wrapperImplementation.collection()));

        // Clone should have the `collection` set.
        assertEq(address(collection), address(wrapper.collection()));

        // Clone should have the same metadata as the ERC-721 collection.
        // `tokenURI` reverts if the token does not exist so cannot test yet.
        assertEq(collection.name(), wrapper.name());
        assertEq(collection.symbol(), wrapper.symbol());
    }

    /*//////////////////////////////////////////////////////////////
                             wrap
    //////////////////////////////////////////////////////////////*/

    function testWrap() external {
        address msgSender = address(this);
        uint256 id = 0;

        collection.mint(msgSender, id);

        assertEq(msgSender, collection.ownerOf(id));
        assertEq(address(0), wrapper.ownerOf(id));

        collection.setApprovalForAll(address(wrapper), true);

        assertTrue(collection.isApprovedForAll(msgSender, address(wrapper)));

        vm.expectEmit(true, true, true, true, address(collection));

        // `Transfer` event emitted by the collection when wrapper calls `safeTransferFrom`.
        emit Transfer(msgSender, address(wrapper), id);

        vm.expectEmit(true, true, true, true, address(wrapper));

        // `Transfer` event emitted by the wrapper in the `onERC721Received` hook.
        emit Transfer(address(0), msgSender, id);

        wrapper.wrap(id);

        assertEq(address(wrapper), collection.ownerOf(id));
        assertEq(msgSender, wrapper.ownerOf(id));
    }
}
