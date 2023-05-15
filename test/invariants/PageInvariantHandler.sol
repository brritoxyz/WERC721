// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Book} from "src/Book.sol";
import {Page} from "src/Page.sol";

contract PageInvariantHandler is Test, ERC721TokenReceiver {
    ERC721 internal constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);
    uint256 internal constant ONE = 1;
    address payable internal constant TIP_RECIPIENT =
        payable(0x9c9dC2110240391d4BEe41203bDFbD19c279B429);

    Book internal immutable book;
    Page internal immutable page;

    uint256[] internal ids = [1, 39, 111];

    receive() external payable {}

    constructor() {
        book = new Book(TIP_RECIPIENT);

        // Set the page implementation (since the version and impl. start at zero)
        book.upgradePage(keccak256("DEPLOYMENT_SALT"), type(Page).creationCode);

        page = Page(book.createPage(LLAMA));

        // Initialize the Page contract
        page.initialize(address(this), LLAMA, TIP_RECIPIENT);

        // Approve the Page contract to transfer our NFTs
        LLAMA.setApprovalForAll(address(page), true);
    }

    function deposit(uint8 id, address recipient) external {
        // "Deal" NFT to self
        address originalOwner = LLAMA.ownerOf(id);

        vm.prank(originalOwner);

        LLAMA.safeTransferFrom(originalOwner, address(this), id);


    }
}
