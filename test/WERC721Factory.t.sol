// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {TestERC721} from "test/lib/TestERC721.sol";
import {WERC721Factory} from "src/WERC721Factory.sol";
import {WERC721} from "src/WERC721.sol";

contract WERC721FactoryTest is Test {
    WERC721Factory public immutable factory = new WERC721Factory();
    address public immutable collection;

    event CreateWrapper(address indexed collection, address indexed wrapper);

    constructor() {
        collection = address(new TestERC721());

        assertTrue(address(0) != address(factory.implementation()));
    }

    /*//////////////////////////////////////////////////////////////
                             create
    //////////////////////////////////////////////////////////////*/

    function testCannotCreateWrapperAlreadyCreated() external {
        factory.create(collection);

        assertTrue(address(0) != factory.wrappers(collection));

        vm.expectRevert(WERC721Factory.WrapperAlreadyCreated.selector);

        factory.create(collection);
    }

    function testCreate() external {
        assertEq(address(0), factory.wrappers(collection));

        vm.expectEmit(true, false, false, false, address(factory));

        emit CreateWrapper(collection, address(0));

        address wrapper = factory.create(collection);

        assertEq(wrapper, factory.wrappers(collection));
        assertEq(collection, address(WERC721(wrapper).collection()));
    }
}
