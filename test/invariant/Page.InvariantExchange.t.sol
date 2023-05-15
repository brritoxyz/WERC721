// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/InvariantTest.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {PageInvariantHandler} from "test/invariant/PageInvariantHandler.sol";
import {Book} from "src/Book.sol";
import {Page} from "src/Page.sol";

contract Collection is ERC721("Collection", "COLLECTION") {
    function mint(address to, uint256 id) external {
        _mint(to, id);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}

contract PageInvariantExchangeTest is Test, InvariantTest {
    address payable internal constant TIP_RECIPIENT =
        payable(0x9c9dC2110240391d4BEe41203bDFbD19c279B429);

    Collection internal collection;
    Book internal book;
    Page internal page;
    PageInvariantHandler internal handler;

    receive() external payable {}

    function setUp() public {
        collection = new Collection();
        book = new Book(TIP_RECIPIENT);

        book.upgradePage(keccak256("DEPLOYMENT_SALT"), type(Page).creationCode);

        page = Page(book.createPage(collection));

        // Deploy and initialize Handler contract
        handler = new PageInvariantHandler(collection, book, page);

        targetContract(address(handler));
    }

    function invariantOwnershipOfAssets() external {
        uint256[] memory ownedIds = handler.getOwnedIds();
        uint256[] memory depositedIds = handler.getDepositedIds();

        unchecked {
            // There MUST NOT be a derivative token if the handler owns the NFT
            for (uint256 i; i < ownedIds.length; ++i) {
                assertEq(collection.ownerOf(ownedIds[i]), address(handler));
                assertEq(page.ownerOf(ownedIds[i]), address(0));
            }

            // There MUST be a derivative token if the Page contract owns the NFT
            for (uint256 i; i < depositedIds.length; ++i) {
                assertEq(collection.ownerOf(depositedIds[i]), address(page));
                assertEq(page.ownerOf(depositedIds[i]), address(handler));
            }
        }
    }
}
