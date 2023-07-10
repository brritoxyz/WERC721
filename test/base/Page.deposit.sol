// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Page} from "src/Page.sol";

contract PageDepositTests is Test {
    struct TestDepositParams {
        address msgSender;
        uint256 id;
        address recipient;
    }

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    function _testDeposit(
        Page page,
        TestDepositParams memory params
    ) internal {
        ERC721 collection = page.collection();

        // Pre-deposit state
        assertEq(params.msgSender, collection.ownerOf(params.id));
        assertEq(address(0), page.ownerOf(params.id));
        assertEq(0, page.balanceOf(params.recipient, params.id));

        vm.prank(params.msgSender);
        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(params.msgSender, address(page), params.id);

        page.deposit(params.id, params.recipient);

        // Post-deposit state
        assertEq(address(page), collection.ownerOf(params.id));
        assertEq(params.recipient, page.ownerOf(params.id));
        assertEq(1, page.balanceOf(params.recipient, params.id));
    }
}
