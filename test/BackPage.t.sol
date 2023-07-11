// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {BackPageBook} from "src/backPage/BackPageBook.sol";
import {BackPage} from "src/backPage/BackPage.sol";
import {Page} from "src/Page.sol";
import {TestERC721} from "test/lib/TestERC721.sol";

contract BackPageTests is Test, ERC721TokenReceiver {
    bytes32 internal constant STORAGE_SLOT_LOCKED = bytes32(uint256(0));
    bytes32 internal constant STORAGE_SLOT_INITIALIZED = bytes32(uint256(1));

    TestERC721 internal immutable collection = new TestERC721();
    BackPageBook internal immutable book = new BackPageBook();
    BackPage internal immutable page;

    address[] internal accounts = [address(1), address(2), address(3)];

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    constructor() {
        // Call `upgradePage` and set the first page implementation
        (uint256 version, ) = book.upgradePage(
            keccak256("DEPLOYMENT_SALT"),
            type(BackPage).creationCode
        );

        // Clone the page implementation and assign to `page` variable
        page = BackPage(book.createPage(collection, version));
    }

    /**
     * @notice Mint an ERC-721 and deposit it for a Page token
     * @param  to  address  Recipient
     * @param  id  uint256  Token ID
     */
    function _mintDeposit(address to, uint256 id) internal {
        collection.mint(to, id);

        vm.startPrank(to);

        collection.setApprovalForAll(address(page), true);
        page.deposit(id, to);

        vm.stopPrank();
    }

    function _batchMintDeposit(address to, uint256 quantity) internal returns (uint256[] memory ids) {
        ids = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; ) {
            ids[i] = i;

            _mintDeposit(to, ids[i]);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             initialize
    //////////////////////////////////////////////////////////////*/

    function testCannotInitializeAlreadyInitialized() external {
        // All deployed pages via Book are initialized
        uint256 locked = uint256(vm.load(address(page), STORAGE_SLOT_LOCKED));
        bool initialized = vm.load(address(page), STORAGE_SLOT_INITIALIZED) ==
            bytes32(abi.encode(bool(true)));

        assertEq(1, locked);
        assertEq(true, initialized);

        vm.expectRevert(Page.AlreadyInitialized.selector);

        Page(address(page)).initialize();
    }

    /*//////////////////////////////////////////////////////////////
                             collection
    //////////////////////////////////////////////////////////////*/

    function testCollection() external {
        assertEq(address(collection), address(page.collection()));
    }

    /*//////////////////////////////////////////////////////////////
                             name
    //////////////////////////////////////////////////////////////*/

    function testName() external {
        string memory collectionName = collection.name();
        string memory pageName = page.name();

        assertEq(
            keccak256(abi.encode(collectionName)),
            keccak256(abi.encode(pageName))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             symbol
    //////////////////////////////////////////////////////////////*/

    function testSymbol() external {
        string memory collectionSymbol = collection.symbol();
        string memory pageSymbol = page.symbol();

        assertEq(
            keccak256(abi.encode(collectionSymbol)),
            keccak256(abi.encode(pageSymbol))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             tokenURI
    //////////////////////////////////////////////////////////////*/

    function testTokenURI(uint256 id) external {
        string memory collectionTokenURI = collection.tokenURI(id);
        string memory pageTokenURI = page.tokenURI(id);

        assertEq(
            keccak256(abi.encode(collectionTokenURI)),
            keccak256(abi.encode(pageTokenURI))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             setApprovalForAll
    //////////////////////////////////////////////////////////////*/

    function testSetApprovalForAllFalseToTrue() external {
        assertFalse(page.isApprovedForAll(address(this), accounts[0]));

        page.setApprovalForAll(accounts[0], true);

        assertTrue(page.isApprovedForAll(address(this), accounts[0]));
    }

    function testSetApprovalForAllTrueToFalse() external {
        page.setApprovalForAll(accounts[0], true);

        assertTrue(page.isApprovedForAll(address(this), accounts[0]));

        page.setApprovalForAll(accounts[0], false);

        assertFalse(page.isApprovedForAll(address(this), accounts[0]));
    }

    function testSetApprovalForAllFuzz(
        address operator,
        bool approved
    ) external {
        page.setApprovalForAll(operator, approved);

        assertEq(approved, page.isApprovedForAll(address(this), operator));
    }

    /*//////////////////////////////////////////////////////////////
                             transfer
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferWrongFrom() external {
        address to = accounts[0];
        uint256 id = 1;

        assertEq(address(0), page.ownerOf(id));

        vm.expectRevert(Page.WrongFrom.selector);

        page.transfer(to, id);
    }

    function testCannotTransferUnsafeRecipient() external {
        address to = address(0);
        uint256 id = 1;

        _mintDeposit(address(this), id);

        assertEq(address(this), page.ownerOf(id));

        vm.expectRevert(Page.UnsafeRecipient.selector);

        page.transfer(to, id);
    }

    function testTransfer() external {
        address to = accounts[0];
        uint256 id = 1;

        _mintDeposit(address(this), id);

        assertEq(address(this), page.ownerOf(id));

        page.transfer(to, id);

        assertEq(to, page.ownerOf(id));
    }

    function testTransferFuzz(uint256 id, address from, address to) external {
        vm.assume(from != address(0));
        vm.assume(from != to);

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));

        bool toIsUnsafe = to == address(0);

        vm.prank(from);

        if (toIsUnsafe) vm.expectRevert(Page.UnsafeRecipient.selector);

        page.transfer(to, id);

        if (!toIsUnsafe) {
            assertEq(to, page.ownerOf(id));
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchTransfer
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchTransferWrongFrom() external {
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[0];
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(0), page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.expectRevert(Page.WrongFrom.selector);

        page.batchTransfer(to, ids);
    }

    function testCannotBatchTransferUnsafeRecipient() external {
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = address(0);
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            _mintDeposit(address(this), ids[i]);

            assertEq(address(this), page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.expectRevert(Page.UnsafeRecipient.selector);

        page.batchTransfer(to, ids);
    }

    function testBatchTransfer() external {
        address[] memory to = new address[](accounts.length);
        uint256[] memory ids = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ) {
            to[i] = accounts[i];
            ids[i] = i;

            _mintDeposit(address(this), ids[i]);

            assertTrue(to[i] != address(0));
            assertEq(address(this), page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        page.batchTransfer(to, ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(to[i], page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             transferFrom
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferFromWrongFrom() external {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        assertEq(address(0), page.ownerOf(id));

        vm.expectRevert(Page.WrongFrom.selector);

        page.transferFrom(from, to, id);
    }

    function testCannotTransferFromUnsafeRecipient() external {
        address from = accounts[0];
        address to = address(0);
        uint256 id = 1;

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));

        vm.expectRevert(Page.UnsafeRecipient.selector);

        page.transferFrom(from, to, id);
    }

    function testCannotTransferFromNotAuthorized() external {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));
        assertFalse(page.isApprovedForAll(from, address(this)));

        vm.expectRevert(Page.NotApproved.selector);

        page.transferFrom(from, to, id);
    }

    function testTransferFromSelf() external {
        address from = address(this);
        address to = accounts[1];
        uint256 id = 1;

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));

        page.transferFrom(from, to, id);

        assertEq(to, page.ownerOf(id));
    }

    function testTransferFrom() external {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));

        vm.prank(from);

        page.setApprovalForAll(address(this), true);

        assertTrue(page.isApprovedForAll(from, address(this)));
        assertTrue(address(this) != from);

        page.transferFrom(from, to, id);

        assertEq(to, page.ownerOf(id));
    }

    function testTransferFromFuzz(
        uint256 id,
        address from,
        address to,
        bool selfTransfer
    ) external {
        vm.assume(from != address(0));
        vm.assume(from != to);

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));

        vm.prank(from);

        if (!selfTransfer) {
            page.setApprovalForAll(address(this), true);

            assertTrue(page.isApprovedForAll(from, address(this)));
            assertTrue(address(this) != from);
        }

        bool toIsUnsafe = to == address(0);

        if (toIsUnsafe) vm.expectRevert(Page.UnsafeRecipient.selector);

        page.transferFrom(from, to, id);

        if (!toIsUnsafe) {
            assertEq(to, page.ownerOf(id));
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchTransferFrom
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchTransferFromNotAuthorized() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        assertFalse(page.isApprovedForAll(from, address(this)));
        assertTrue(from != address(this));

        vm.expectRevert(Page.NotApproved.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromWrongFromSelf() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(0), page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);
        vm.expectRevert(Page.WrongFrom.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromWrongFrom() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(0), page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);

        page.setApprovalForAll(address(this), true);

        assertTrue(page.isApprovedForAll(from, address(this)));

        vm.expectRevert(Page.WrongFrom.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromUnsafeRecipientSelf() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = address(0);
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            _mintDeposit(from, ids[i]);

            assertEq(from, page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);
        vm.expectRevert(Page.UnsafeRecipient.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromUnsafeRecipient() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = address(0);
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            _mintDeposit(from, ids[i]);

            assertEq(from, page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);

        page.setApprovalForAll(address(this), true);

        assertTrue(page.isApprovedForAll(from, address(this)));

        vm.expectRevert(Page.UnsafeRecipient.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testBatchTransferFromSelf() external {
        address from = address(1);
        address[] memory to = new address[](accounts.length);
        uint256[] memory ids = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ) {
            to[i] = accounts[i];
            ids[i] = i;

            _mintDeposit(from, ids[i]);

            assertEq(from, page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);

        page.batchTransferFrom(from, to, ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(to[i], page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchTransferFrom() external {
        address from = address(1);
        address[] memory to = new address[](accounts.length);
        uint256[] memory ids = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ) {
            to[i] = accounts[i];
            ids[i] = i;

            _mintDeposit(from, ids[i]);

            assertEq(from, page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);

        page.setApprovalForAll(address(this), true);

        assertTrue(page.isApprovedForAll(from, address(this)));

        page.batchTransferFrom(from, to, ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(to[i], page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
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

        // Page must be approved to transfer tokens on behalf of the sender
        assertTrue(collection.isApprovedForAll(msgSender, address(page)));

        // Pre-deposit state
        assertEq(msgSender, collection.ownerOf(id));
        assertEq(address(0), page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(msgSender, address(page), id);

        page.deposit(id, recipient);

        // Post-deposit state
        assertEq(address(page), collection.ownerOf(id));
        assertEq(recipient, page.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             batchDeposit
    //////////////////////////////////////////////////////////////*/

    function testBatchDeposit() external {
        uint256 quantity = 5;
        uint256[] memory ids = new uint256[](quantity);
        address msgSender = address(this);
        address recipient = accounts[0];

        for (uint256 i = 0; i < ids.length; ) {
            ids[i] = i;

            collection.mint(msgSender, ids[i]);

            assertEq(address(0), page.ownerOf(ids[i]));
            assertEq(msgSender, collection.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.startPrank(msgSender);

        collection.setApprovalForAll(address(page), true);
        page.batchDeposit(ids, recipient);

        vm.stopPrank();

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(recipient, page.ownerOf(ids[i]));
            assertEq(address(page), collection.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             withdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotWithdrawRecipientZero() external {
        address msgSender = address(this);
        uint256 id = 0;
        address recipient = address(0);

        _mintDeposit(msgSender, id);

        vm.prank(msgSender);
        vm.expectRevert(ERC721.TransferToZeroAddress.selector);

        page.withdraw(id, recipient);
    }

    function testCannotWithdrawMsgSenderUnauthorized() external {
        address owner = address(this);
        address msgSender = accounts[0];
        uint256 id = 0;
        address recipient = accounts[1];

        _mintDeposit(owner, id);

        assertTrue(msgSender != page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(Page.Unauthorized.selector);

        page.withdraw(id, recipient);
    }

    function testWithdraw() external {
        address msgSender = address(this);
        uint256 id = 0;
        address recipient = accounts[0];

        _mintDeposit(msgSender, id);

        assertEq(msgSender, page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(address(page), recipient, id);

        page.withdraw(id, recipient);

        assertEq(address(0), page.ownerOf(id));
        assertEq(recipient, collection.ownerOf(id));
    }
}
