// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {BackPageBook} from "src/backPage/BackPageBook.sol";
import {BackPage} from "src/backPage/BackPage.sol";
import {TestERC721} from "test/lib/TestERC721.sol";
import {PageTests} from "test/PageTests.sol";

contract BackPageTests is Test, ERC721TokenReceiver, PageTests {
    TestERC721 internal immutable collection = new TestERC721();
    BackPageBook internal immutable book = new BackPageBook();
    BackPage internal immutable page;

    constructor() {
        // Call `upgradePage` and set the first page implementation
        (uint256 version, ) = book.upgradePage(
            keccak256("DEPLOYMENT_SALT"),
            type(BackPage).creationCode
        );

        // Clone the page implementation and assign to `page` variable
        page = BackPage(book.createPage(collection, version));
    }

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testDeposit() external {
        address msgSender = address(this);
        uint256 id = 0;
        address recipient = address(1);

        collection.mint(msgSender, id);
        collection.setApprovalForAll(address(page), true);

        _deposit(page, msgSender, id, recipient);
    }
}
