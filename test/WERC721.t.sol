// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {TestERC721} from "test/lib/TestERC721.sol";
import {WERC721Factory} from "src/WERC721Factory.sol";
import {WERC721} from "src/WERC721.sol";

contract WERC721Test is Test {
    TestERC721 public immutable collection;
    WERC721Factory private immutable factory;
    WERC721 private immutable wrappedImplementation;
    WERC721 private immutable wrapped;

    constructor() {
        collection = new TestERC721();
        factory = new WERC721Factory();
        wrappedImplementation = factory.implementation();
        wrapped = WERC721(factory.create(collection));

        assertTrue(address(wrappedImplementation) != address(0));
        assertTrue(address(wrapped) != address(0));

        // Implementation should not have `collection` set.
        assertEq(address(0), address(wrappedImplementation.collection()));

        // Clone should have the `collection` set.
        assertEq(address(collection), address(wrapped.collection()));
    }
}
