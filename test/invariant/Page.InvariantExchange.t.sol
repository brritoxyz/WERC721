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

    function assertOwnedState(uint256 id, address collectionOwnerOf) internal {
        // Handler has custody of the NFT
        assertEq(collectionOwnerOf, collection.ownerOf(id));

        // No derivative should exist
        assertEq(address(0), page.ownerOf(id));

        // Listing should be empty
        (address seller, uint48 price, uint48 tip) = page.listings(id);

        assertEq(address(0), seller);
        assertEq(0, price);
        assertEq(0, tip);
    }

    function invariantOwnedState() external {
        uint256[] memory ids = handler.getIds();
        uint256 id;

        // There MUST NOT be a derivative token if the handler owns the NFT
        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            // Increment before the remaining logic since we are conditionally skipping
            unchecked {
                ++i;
            }

            // If the token ID is not in an "owned" state, continue to the next ID
            if (handler.states(id) != PageInvariantHandler.State.Owned)
                continue;

            assertOwnedState(id, address(handler));
        }
    }
}
