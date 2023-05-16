// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/InvariantTest.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
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

    function ownerOf(uint256 id) public view override returns (address owner) {
        return _ownerOf[id] == address(0) ? address(0) : _ownerOf[id];
    }
}

contract PageInvariantExchangeTest is Test, InvariantTest, ERC721TokenReceiver {
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

        // Test runner will only call the Handler contract
        targetContract(address(handler));

        address[] memory senders = new address[](10);
        senders[0] = address(this);
        senders[1] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        senders[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        senders[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        senders[4] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        senders[5] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        senders[6] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
        senders[7] = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;
        senders[8] = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
        senders[9] = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

        unchecked {
            for (uint256 i; i < senders.length; ++i) {
                // Calls the Handler contract as the following sender address (speeds up tests)
                targetSender(senders[i]);
            }
        }

        // Exclude contracts deployed in setUp method (automatically added)
        excludeContract(address(collection));
        excludeContract(address(book));
        excludeContract(address(page));
        excludeContract(address(this));
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

    function invariantTokenState() external {
        uint256[] memory ids = handler.getIds();

        if (ids.length == 0) return;

        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[ids.length - 1];
            (
                address recipient,
                PageInvariantHandler.TokenState tokenState
            ) = handler.states(id);

            unchecked {
                ++i;
            }

            // If the token ID is not in an "deposited" state, continue to the next ID
            if (tokenState == PageInvariantHandler.TokenState.Deposited) {
                address pageOwnerOf = recipient;

                assertDepositedState(id, pageOwnerOf);

                return;
            }

            if (tokenState == PageInvariantHandler.TokenState.Withdrawn) {
                address collectionOwnerOf = recipient;

                assertWithdrawnState(id, collectionOwnerOf);

                return;
            }

            if (
                tokenState == PageInvariantHandler.TokenState.Listed ||
                tokenState == PageInvariantHandler.TokenState.Edited
            ) {
                address listingSeller = recipient;

                assertListedState(id, listingSeller);

                return;
            }

            if (tokenState == PageInvariantHandler.TokenState.Canceled) {
                address pageOwnerOf = recipient;

                assertCanceledState(id, pageOwnerOf);

                return;
            }

            // Revert if no state is matched
            revert("Invalid state");
        }
    }
}
