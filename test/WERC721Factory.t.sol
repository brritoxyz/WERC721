// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {TestERC721} from "test/lib/TestERC721.sol";
import {WERC721Factory} from "src/WERC721Factory.sol";
import {WERC721} from "src/WERC721.sol";

contract WERC721FactoryTest is Test {
    WERC721Factory private immutable factory = new WERC721Factory();
    TestERC721 private immutable collection = new TestERC721();

    event CreateWrapper(ERC721 indexed collection, WERC721 indexed wrapper);

    constructor() {
        assertTrue(address(0) != address(factory.implementation()));
    }

    /*//////////////////////////////////////////////////////////////
                             create
    //////////////////////////////////////////////////////////////*/

    function testCannotCreateInvalidCollectionAddress() external {
        vm.expectRevert(WERC721Factory.InvalidCollectionAddress.selector);

        factory.create(ERC721(address(0)));
    }

    function testCannotCreateWrapperAlreadyCreated() external {
        factory.create(collection);

        assertTrue(address(0) != address(factory.wrappers(collection)));

        vm.expectRevert(WERC721Factory.WrapperAlreadyCreated.selector);

        factory.create(collection);
    }

    function testCreate() external {
        assertEq(address(0), address(factory.wrappers(collection)));

        vm.expectEmit(true, false, false, false, address(factory));

        emit CreateWrapper(collection, WERC721(address(0)));

        WERC721 wrapper = factory.create(collection);

        assertEq(address(wrapper), address(factory.wrappers(collection)));
        assertEq(address(collection), address(wrapper.collection()));
    }
}
