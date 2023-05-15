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

    function assertDepositedState(uint256 id, address pageOwnerOf) internal {
        // The page has custody of the NFT when it is deposited
        assertEq(address(page), collection.ownerOf(id));

        // The derivative should be owned by the depositor
        assertEq(pageOwnerOf, page.ownerOf(id));

        // Listing should be empty
        (address seller, uint48 price, uint48 tip) = page.listings(id);

        assertEq(address(0), seller);
        assertEq(0, price);
        assertEq(0, tip);
    }

    function assertWithdrawnState(
        uint256 id,
        address collectionOwnerOf
    ) internal {
        // Handler has custody of the NFT when it is withdrawn
        assertEq(collectionOwnerOf, collection.ownerOf(id));

        // No derivative should exist
        assertEq(address(0), page.ownerOf(id));

        // Listing should be empty
        (address seller, uint48 price, uint48 tip) = page.listings(id);

        assertEq(address(0), seller);
        assertEq(0, price);
        assertEq(0, tip);
    }

    function assertListedState(uint256 id, address listingSeller) internal {
        // The page has custody of the NFT since it is deposited
        assertEq(address(page), collection.ownerOf(id));

        // The page should have custody of the derivative to prevent double-listing
        assertEq(address(page), page.ownerOf(id));

        // Listing is not empty
        (address seller, uint48 price, uint48 tip) = page.listings(id);

        assertTrue(listingSeller != address(0));
        assertEq(listingSeller, seller);

        // The listing price cannot be zero
        assertGt(price, 0);

        // The listing price must always be greater than or equal to the tip
        assertGe(price, tip);
    }

    function assertCanceledState(uint256 id, address pageOwnerOf) internal {
        // The page has custody of the NFT since it is deposited
        assertEq(address(page), collection.ownerOf(id));

        // The derivative should be owned by the listing canceller
        assertEq(pageOwnerOf, page.ownerOf(id));

        // Listing is empty
        (address seller, uint48 price, uint48 tip) = page.listings(id);

        assertEq(address(0), seller);
        assertEq(0, price);
        assertEq(0, tip);
    }

    function invariantDepositedState() external {
        uint256[] memory ids = handler.getIds();
        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            // Increment before the remaining logic since we are conditionally skipping
            unchecked {
                ++i;
            }

            // If the token ID is not in an "deposited" state, continue to the next ID
            if (handler.states(id) != PageInvariantHandler.State.Deposited)
                continue;

            address pageOwnerOf = address(handler);

            assertDepositedState(id, pageOwnerOf);
        }
    }

    function invariantWithdrawnState() external {
        uint256[] memory ids = handler.getIds();
        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            unchecked {
                ++i;
            }

            if (handler.states(id) != PageInvariantHandler.State.Withdrawn)
                continue;

            address collectionOwnerOf = address(handler);

            assertWithdrawnState(id, collectionOwnerOf);
        }
    }

    function invariantListedState() external {
        uint256[] memory ids = handler.getIds();
        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            unchecked {
                ++i;
            }

            if (handler.states(id) != PageInvariantHandler.State.Listed)
                continue;

            address listingSeller = address(handler);

            assertListedState(id, listingSeller);
        }
    }

    function invariantEditedState() external {
        uint256[] memory ids = handler.getIds();
        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            unchecked {
                ++i;
            }

            if (handler.states(id) != PageInvariantHandler.State.Edited)
                continue;

            address listingSeller = address(handler);

            assertListedState(id, listingSeller);
        }
    }

    function invariantCanceledState() external {
        uint256[] memory ids = handler.getIds();
        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            unchecked {
                ++i;
            }

            if (handler.states(id) != PageInvariantHandler.State.Canceled)
                continue;

            address pageOwnerOf = address(handler);

            assertCanceledState(id, pageOwnerOf);
        }
    }
}
