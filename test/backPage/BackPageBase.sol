// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Book} from "src/Book.sol";
import {BackPage} from "src/backPage/BackPage.sol";

contract BackPageBase is Test, ERC721TokenReceiver {
    ERC721 internal constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);
    uint256 internal constant ONE = 1;

    Book internal immutable book;
    BackPage internal immutable page;

    uint256[] internal ids = [1, 39, 111];
    address[] internal accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    // Test accounts with duplicates (to test offer quantity increase)
    address[] internal offerAccounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8
    ];

    receive() external payable {}

    constructor() {
        book = new Book();

        // Set the page implementation (since the version and impl. start at zero)
        book.upgradePage(keccak256("DEPLOYMENT_SALT"), type(BackPage).creationCode);

        page = BackPage(book.createPage(LLAMA));

        // Verify that page cannot be initialized again
        vm.expectRevert(BackPage.AlreadyInitialized.selector);

        page.initialize();

        for (uint256 i = 0; i < ids.length; ) {
            address originalOwner = LLAMA.ownerOf(ids[i]);

            vm.prank(originalOwner);

            LLAMA.safeTransferFrom(originalOwner, address(this), ids[i]);

            unchecked {
                ++i;
            }
        }

        LLAMA.setApprovalForAll(address(page), true);
    }
}
