// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Page} from "src/Page.sol";

contract PageTests is Test {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    function _deposit(
        Page page,
        address msgSender,
        uint256 id,
        address recipient
    ) internal {
        ERC721 collection = page.collection();

        // Page must be approved to transfer tokens on behalf of the sender
        assertTrue(collection.isApprovedForAll(msgSender, address(page)));

        // Pre-deposit state
        assertEq(msgSender, collection.ownerOf(id));
        assertEq(address(0), page.ownerOf(id));
        assertEq(0, page.balanceOf(recipient, id));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(msgSender, address(page), id);

        page.deposit(id, recipient);

        // Post-deposit state
        assertEq(address(page), collection.ownerOf(id));
        assertEq(recipient, page.ownerOf(id));
        assertEq(1, page.balanceOf(recipient, id));
    }
}
