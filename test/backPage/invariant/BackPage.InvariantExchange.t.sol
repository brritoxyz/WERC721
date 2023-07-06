// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {BackPageInvariantHandler} from "test/backPage/invariant/BackPageInvariantHandler.sol";
import {Book} from "src/Book.sol";
import {BackPage} from "src/backPage/BackPage.sol";

contract Collection is ERC721 {
    function name() public pure override returns (string memory) {
        return "Test";
    }

    function symbol() public pure override returns (string memory) {
        return "TEST";
    }

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    function ownerOf(uint256 id) public view override returns (address owner) {
        return _ownerOf(id) == address(0) ? address(0) : _ownerOf(id);
    }
}

contract PageInvariantExchangeTest is StdInvariant, Test, ERC721TokenReceiver {
    address payable internal constant TIP_RECIPIENT =
        payable(0x9c9dC2110240391d4BEe41203bDFbD19c279B429);

    Collection internal collection;
    Book internal book;
    BackPage internal page;
    BackPageInvariantHandler internal handler;
    address[] internal senders = [
        address(this),
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
        0x976EA74026E726554dB657fA54763abd0C3a0aa9,
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,
        0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f,
        0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
    ];

    // Specify target selectors to avoid calling handler getter methods
    bytes4[] selectors = [
        BackPageInvariantHandler.mintDeposit.selector,
        BackPageInvariantHandler.deposit.selector,
        BackPageInvariantHandler.withdraw.selector,
        BackPageInvariantHandler.list.selector,
        BackPageInvariantHandler.edit.selector,
        BackPageInvariantHandler.cancel.selector,
        BackPageInvariantHandler.buy.selector
    ];

    receive() external payable {}

    function setUp() public {
        collection = new Collection();
        book = new Book();

        book.upgradePage(keccak256("DEPLOYMENT_SALT"), type(BackPage).creationCode);

        page = BackPage(book.createPage(collection));

        // Deploy and initialize Handler contract
        handler = new BackPageInvariantHandler(collection, book, page);

        unchecked {
            for (uint256 i = 0; i < senders.length; ++i) {
                // Calls the Handler contract as the following sender address (speeds up tests)
                targetSender(senders[i]);
            }
        }

        // Test runner should only call the Handler contract
        targetContract(address(handler));

        // Exclude contracts deployed in setUp method (automatically added)
        excludeContract(address(collection));
        excludeContract(address(book));
        excludeContract(address(page));

        targetSelector(StdInvariant.FuzzSelector(address(handler), selectors));
    }

    function assertDepositedState(uint256 id, address pageOwnerOf) internal {
        // The page has custody of the NFT when it is deposited
        assertEq(address(page), collection.ownerOf(id));

        // The derivative should be owned by the depositor
        assertEq(pageOwnerOf, page.ownerOf(id));

        // Listing should be empty
        (address seller, uint96 price) = page.listings(id);

        assertEq(address(0), seller);
        assertEq(0, price);
    }

    function assertWithdrawnState(
        uint256 id,
        address collectionOwnerOf
    ) internal {
        // Withdrawer has custody of the NFT when it is withdrawn
        assertEq(collectionOwnerOf, collection.ownerOf(id));

        // No derivative should exist when the NFT is withdrawn
        assertEq(address(0), page.ownerOf(id));

        // Listing should be empty
        (address seller, uint96 price) = page.listings(id);

        assertEq(address(0), seller);
        assertEq(0, price);
    }

    function assertListedState(uint256 id, address listingSeller) internal {
        // The page has custody of the NFT since it is deposited
        assertEq(address(page), collection.ownerOf(id));

        // The page should have custody of the derivative to prevent double-listing
        assertEq(address(page), page.ownerOf(id));

        // Listing is not empty
        (address seller, uint96 price) = page.listings(id);

        assertTrue(listingSeller != address(0));
        assertEq(listingSeller, seller);

        // The listing price cannot be zero
        assertGt(price, 0);
    }

    function assertCanceledState(uint256 id, address pageOwnerOf) internal {
        // The page has custody of the NFT since it is deposited
        assertEq(address(page), collection.ownerOf(id));

        // The derivative should be owned by the listing canceller
        assertEq(pageOwnerOf, page.ownerOf(id));

        // Listing is empty
        (address seller, uint96 price) = page.listings(id);

        assertEq(address(0), seller);
        assertEq(0, price);
    }

    function assertBoughtState(uint256 id, address pageOwnerOf) internal {
        // The page has custody of the NFT since it is deposited
        assertEq(address(page), collection.ownerOf(id));

        // The derivative should be owned by the listing buyer
        assertEq(pageOwnerOf, page.ownerOf(id));

        // Listing is empty
        (address seller, uint96 price) = page.listings(id);

        assertEq(address(0), seller);
        assertEq(0, price);
    }

    function invariantTokenState() external {
        uint256[] memory ids = handler.getIds();

        if (ids.length == 0) return;

        uint256 id;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[ids.length - 1];
            (
                address recipient,
                BackPageInvariantHandler.TokenState tokenState
            ) = handler.states(id);

            unchecked {
                ++i;
            }

            // If the token ID is not in an "deposited" state, continue to the next ID
            if (tokenState == BackPageInvariantHandler.TokenState.Deposited) {
                address pageOwnerOf = recipient;

                assertDepositedState(id, pageOwnerOf);

                return;
            }

            if (tokenState == BackPageInvariantHandler.TokenState.Withdrawn) {
                address collectionOwnerOf = recipient;

                assertWithdrawnState(id, collectionOwnerOf);

                return;
            }

            if (
                tokenState == BackPageInvariantHandler.TokenState.Listed ||
                tokenState == BackPageInvariantHandler.TokenState.Edited
            ) {
                address listingSeller = recipient;

                assertListedState(id, listingSeller);

                return;
            }

            if (tokenState == BackPageInvariantHandler.TokenState.Canceled) {
                address pageOwnerOf = recipient;

                assertCanceledState(id, pageOwnerOf);

                return;
            }

            if (tokenState == BackPageInvariantHandler.TokenState.Bought) {
                address pageOwnerOf = recipient;

                assertBoughtState(id, pageOwnerOf);

                return;
            }

            // Revert if no state is matched
            revert("Invalid state");
        }
    }
}
