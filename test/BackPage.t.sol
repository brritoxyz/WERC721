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
    event List(uint256 id);
    event Edit(uint256 id);
    event Cancel(uint256 id);
    event BatchList(uint256[] ids);
    event BatchEdit(uint256[] ids);
    event BatchCancel(uint256[] ids);
    event Buy(uint256 id);
    event BatchBuy(uint256[] ids);
    event MakeOffer(address maker);
    event CancelOffer(address maker);
    event TakeOffer(address taker);

    receive() external payable {}

    constructor() {
        // Call `upgradePage` and set the first page implementation
        (uint256 version, ) = book.upgradePage(
            keccak256("DEPLOYMENT_SALT"),
            type(BackPage).creationCode
        );

        // Clone the page implementation and assign to `page` variable
        page = BackPage(book.createPage(collection, version));
    }

    function _mintDeposit(address to, uint256 id) internal {
        collection.mint(to, id);

        vm.startPrank(to);

        collection.setApprovalForAll(address(page), true);
        page.deposit(id, to);

        vm.stopPrank();

        // Checks to verify token ownership of the J.Page and ERC-721 tokens
        assertEq(to, page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));
    }

    function _batchMintDeposit(
        address to,
        uint256 quantity
    ) internal returns (uint256[] memory ids) {
        ids = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; ) {
            ids[i] = i;

            _mintDeposit(to, ids[i]);

            unchecked {
                ++i;
            }
        }
    }

    function _mintDepositList(address to, uint256 id, uint96 price) internal {
        _mintDeposit(to, id);

        vm.prank(to);
        vm.expectEmit(true, false, false, false, address(page));

        emit List(id);

        page.list(id, price);

        (address listingSeller, uint96 listingPrice) = page.listings(id);

        assertEq(to, listingSeller);
        assertEq(price, listingPrice);
        assertEq(address(page), page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));
    }

    function _batchMintDepositList(
        address to,
        uint256 quantity
    ) internal returns (uint256[] memory ids, uint96[] memory prices) {
        ids = new uint256[](quantity);
        prices = new uint96[](quantity);

        for (uint256 i = 0; i < quantity; ) {
            ids[i] = i;
            prices[i] = uint96(1 ether) * uint96(i + 1);

            _mintDepositList(to, ids[i], prices[i]);

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
            bytes32(abi.encode(true));

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

    function testCannotTransferNotOwner() external {
        address to = accounts[0];
        uint256 id = 1;

        assertEq(address(0), page.ownerOf(id));

        vm.expectRevert(Page.NotOwner.selector);

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

    function testCannotBatchTransferNotOwner() external {
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

        vm.expectRevert(Page.NotOwner.selector);

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

    function testCannotTransferFromNotOwner() external {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        assertEq(address(0), page.ownerOf(id));

        vm.expectRevert(Page.NotOwner.selector);

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

    function testCannotBatchTransferFromNotOwnerSelf() external {
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
        vm.expectRevert(Page.NotOwner.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromNotOwner() external {
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

        vm.expectRevert(Page.NotOwner.selector);

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

    function testCannotWithdrawMsgSenderNotOwner() external {
        address owner = address(this);
        address msgSender = accounts[0];
        uint256 id = 0;
        address recipient = accounts[1];

        _mintDeposit(owner, id);

        assertTrue(msgSender != page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(Page.NotOwner.selector);

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

    /*//////////////////////////////////////////////////////////////
                             batchWithdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchWithdrawRecipientZero() external {
        address msgSender = address(this);
        uint256 mintQuantity = 5;
        uint256[] memory ids = _batchMintDeposit(msgSender, mintQuantity);
        address recipient = address(0);

        vm.prank(msgSender);
        vm.expectRevert(ERC721.TransferToZeroAddress.selector);

        page.batchWithdraw(ids, recipient);
    }

    function testCannotBatchWithdrawMsgSenderNotOwner() external {
        address owner = address(this);
        address unauthorizedMsgSender = accounts[0];
        uint256 mintQuantity = 5;
        uint256[] memory ids = _batchMintDeposit(owner, mintQuantity);
        address recipient = accounts[0];

        for (uint256 i = 0; i < ids.length; ) {
            assertTrue(unauthorizedMsgSender != page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.batchWithdraw(ids, recipient);
    }

    function testBatchWithdraw() external {
        address msgSender = address(this);
        uint256 mintQuantity = 5;
        uint256[] memory ids = _batchMintDeposit(msgSender, mintQuantity);
        address recipient = accounts[0];

        vm.prank(msgSender);

        page.batchWithdraw(ids, recipient);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(0), page.ownerOf(ids[i]));
            assertEq(recipient, collection.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             list
    //////////////////////////////////////////////////////////////*/

    function testCannotListNotOwner() external {
        address owner = address(this);
        address unauthorizedMsgSender = accounts[0];
        uint256 id = 0;
        uint96 price = 1 ether;

        _mintDeposit(owner, id);

        assertTrue(unauthorizedMsgSender != page.ownerOf(id));

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.list(id, price);
    }

    function testCannotListInvalidPrice() external {
        address msgSender = address(this);
        uint256 id = 0;
        uint96 price = 0;

        _mintDeposit(msgSender, id);

        vm.prank(msgSender);
        vm.expectRevert(Page.InvalidPrice.selector);

        page.list(id, price);
    }

    function testList(address msgSender, uint256 id, uint96 price) external {
        vm.assume(msgSender != address(0));
        vm.assume(price != 0);

        _mintDeposit(msgSender, id);

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit List(id);

        page.list(id, price);

        (address listingSeller, uint96 listingPrice) = page.listings(id);

        assertEq(msgSender, listingSeller);
        assertEq(price, listingPrice);
        assertEq(address(page), page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             edit
    //////////////////////////////////////////////////////////////*/

    function testCannotEditInvalidPrice() external {
        address msgSender = address(this);
        uint256 id = 0;
        uint96 price = 1 ether;
        uint96 newPrice = 0;

        _mintDepositList(msgSender, id, price);

        vm.prank(msgSender);
        vm.expectRevert(Page.InvalidPrice.selector);

        page.edit(id, newPrice);
    }

    function testCannotEditNotSeller() external {
        address owner = address(this);
        address msgSender = accounts[0];
        uint256 id = 0;
        uint96 price = 1 ether;
        uint96 newPrice = 2 ether;

        _mintDepositList(owner, id, price);

        (address listingSeller, ) = page.listings(id);

        assertTrue(msgSender != listingSeller);

        vm.prank(msgSender);
        vm.expectRevert(Page.NotSeller.selector);

        page.edit(id, newPrice);
    }

    function testEdit(
        address msgSender,
        uint256 id,
        uint96 price,
        uint96 newPrice
    ) external {
        vm.assume(msgSender != address(0));
        vm.assume(price != 0);
        vm.assume(newPrice != 0);
        vm.assume(newPrice != price);

        _mintDepositList(msgSender, id, price);

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit Edit(id);

        page.edit(id, newPrice);

        (address listingSeller, uint96 listingPrice) = page.listings(id);

        assertEq(msgSender, listingSeller);
        assertEq(newPrice, listingPrice);
    }

    /*//////////////////////////////////////////////////////////////
                             cancel
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelNotSeller() external {
        address owner = address(this);
        address unauthorizedMsgSender = accounts[0];
        uint256 id = 0;
        uint96 price = 1 ether;

        _mintDepositList(owner, id, price);

        (address listingSeller, ) = page.listings(id);

        assertTrue(unauthorizedMsgSender != listingSeller);

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(Page.NotSeller.selector);

        page.cancel(id);
    }

    function testCancel(address msgSender, uint256 id, uint96 price) external {
        vm.assume(msgSender != address(0));
        vm.assume(price != 0);

        _mintDepositList(msgSender, id, price);

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit Cancel(id);

        page.cancel(id);

        (address listingSeller, uint96 listingPrice) = page.listings(id);

        assertEq(address(0), listingSeller);
        assertEq(0, listingPrice);
        assertEq(msgSender, page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             buy
    //////////////////////////////////////////////////////////////*/

    function testCannotBuyInsufficientMsgValue(bool shouldList) external {
        address seller = address(this);
        address msgSender = accounts[0];
        uint256 id = 0;
        uint96 price = 1 ether;
        uint256 insufficientMsgValue = price - 1;

        // Reverts with `InsufficientMsValue` if msg.value is insufficient
        if (shouldList) {
            _mintDepositList(seller, id, price);

            vm.expectRevert(Page.InsufficientMsgValue.selector);
        } else {
            // Reverts with `NotListed` if listing does not exist
            vm.expectRevert(Page.NotListed.selector);
        }

        vm.deal(msgSender, price);
        vm.prank(msgSender);

        // Attempt to buy with msg.value less than price
        page.buy{value: insufficientMsgValue}(id);
    }

    function testBuy(address msgSender, uint256 id, uint96 price) external {
        vm.assume(msgSender != address(0));
        vm.assume(msgSender != address(this));
        vm.assume(price != 0);
        vm.deal(msgSender, price);

        // Set `seller` to this address to avoid reversions from contract accounts w/o fallback methods
        address seller = address(this);

        _mintDepositList(seller, id, price);

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = msgSender.balance;

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit Buy(id);

        page.buy{value: price}(id);

        (address listingSeller, uint96 listingPrice) = page.listings(id);

        assertEq(address(0), listingSeller);
        assertEq(0, listingPrice);
        assertEq(sellerBalanceBefore + price, seller.balance);
        assertEq(buyerBalanceBefore - price, msgSender.balance);
        assertEq(msgSender, page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             batchList
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchListMismatchedArrayInvalid() external {
        address msgSender = address(this);
        uint256 mintQuantity = 5;
        uint256[] memory ids = _batchMintDeposit(msgSender, mintQuantity);
        uint96[] memory prices = new uint96[](0);

        assertTrue(ids.length != prices.length);

        vm.expectRevert(stdError.indexOOBError);

        page.batchList(ids, prices);
    }

    function testBatchList(
        uint96 price1,
        uint96 price2,
        uint96 price3
    ) external {
        vm.assume(price1 != 0);
        vm.assume(price2 != 0);
        vm.assume(price3 != 0);

        address msgSender = address(this);

        // Must be updated depending on the number of price params
        uint256 mintQuantity = 3;

        uint256[] memory ids = _batchMintDeposit(msgSender, mintQuantity);
        uint96[] memory prices = new uint96[](ids.length);
        prices[0] = price1;
        prices[1] = price2;
        prices[2] = price3;

        assertEq(ids.length, prices.length);

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchList(ids);

        page.batchList(ids, prices);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address listingSeller, uint96 listingPrice) = page.listings(id);

            assertEq(msgSender, listingSeller);
            assertEq(prices[i], listingPrice);
            assertEq(address(page), page.ownerOf(id));
            assertEq(address(page), collection.ownerOf(id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchEdit
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchEditMismatchedArrayInvalid() external {
        address msgSender = address(this);
        uint256 listQuantity = 5;
        (uint256[] memory ids, ) = _batchMintDepositList(
            msgSender,
            listQuantity
        );
        uint96[] memory newPrices = new uint96[](0);

        vm.prank(msgSender);
        vm.expectRevert(stdError.indexOOBError);

        page.batchEdit(ids, newPrices);
    }

    function testCannotBatchEditInvalidPrice() external {
        address msgSender = address(this);
        uint256 listQuantity = 5;
        (uint256[] memory ids, ) = _batchMintDepositList(
            msgSender,
            listQuantity
        );
        uint96[] memory newPrices = new uint96[](ids.length);

        vm.prank(msgSender);
        vm.expectRevert(Page.InvalidPrice.selector);

        page.batchEdit(ids, newPrices);
    }

    function testCannotBatchEditNotSeller() external {
        address owner = address(this);
        address unauthorizedMsgSender = accounts[0];
        uint256 listQuantity = 5;
        (uint256[] memory ids, ) = _batchMintDepositList(owner, listQuantity);
        uint96[] memory newPrices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            newPrices[i] = 1 ether;

            unchecked {
                ++i;
            }
        }

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(Page.NotSeller.selector);

        page.batchEdit(ids, newPrices);
    }

    function testBatchEdit(address msgSender, uint8 listQuantity) external {
        vm.assume(msgSender != address(0));
        vm.assume(listQuantity != 0);

        (uint256[] memory ids, uint96[] memory prices) = _batchMintDepositList(
            msgSender,
            listQuantity
        );
        uint96[] memory newPrices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            newPrices[i] = prices[i] - uint96(i);

            unchecked {
                ++i;
            }
        }

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchEdit(ids);

        page.batchEdit(ids, newPrices);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address listingSeller, uint96 listingPrice) = page.listings(id);

            assertEq(msgSender, listingSeller);
            assertEq(newPrices[id], listingPrice);
            assertEq(address(page), page.ownerOf(id));
            assertEq(address(page), collection.ownerOf(id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchCancel
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchCancelNotSeller() external {
        address owner = address(this);
        address unauthorizedMsgSender = accounts[0];
        uint256 listQuantity = 5;
        (uint256[] memory ids, ) = _batchMintDepositList(owner, listQuantity);

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(Page.NotSeller.selector);

        page.batchCancel(ids);
    }

    function testBatchCancel(address msgSender, uint8 listQuantity) external {
        vm.assume(msgSender != address(0));
        vm.assume(listQuantity != 0);

        (uint256[] memory ids, ) = _batchMintDepositList(
            msgSender,
            listQuantity
        );

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchCancel(ids);

        page.batchCancel(ids);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address listingSeller, uint96 listingPrice) = page.listings(id);

            assertEq(address(0), listingSeller);
            assertEq(0, listingPrice);
            assertEq(msgSender, page.ownerOf(id));
            assertEq(address(page), collection.ownerOf(id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchBuy
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchBuyMsgValueInsufficient() external {
        address seller = address(this);
        address msgSender = accounts[0];
        uint256 listQuantity = 5;
        (uint256[] memory ids, uint96[] memory prices) = _batchMintDepositList(
            seller,
            listQuantity
        );
        uint256 totalPrice;

        for (uint256 i = 0; i < ids.length; ) {
            totalPrice += uint256(prices[i]);

            unchecked {
                ++i;
            }
        }

        uint256 insufficientMsgValue = totalPrice - 1;

        vm.deal(msgSender, totalPrice);
        vm.prank(msgSender);
        vm.expectRevert(stdError.arithmeticError);

        // Send an insufficient amount of ETH
        page.batchBuy{value: insufficientMsgValue}(ids);
    }

    function testBatchBuy(address msgSender, uint8 listQuantity) external {
        vm.assume(msgSender != address(0));
        vm.assume(listQuantity != 0);

        // Set `seller` to this address to avoid reversions from contract accounts w/o fallback methods
        address seller = address(this);

        (uint256[] memory ids, uint96[] memory prices) = _batchMintDepositList(
            seller,
            listQuantity
        );
        uint256 totalPrice;

        for (uint256 i = 0; i < ids.length; ) {
            totalPrice += uint256(prices[i]);

            unchecked {
                ++i;
            }
        }

        vm.deal(msgSender, totalPrice);

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = msgSender.balance;

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchBuy(ids);

        // Send enough ETH to cover seller proceeds
        page.batchBuy{value: totalPrice}(ids);

        assertEq(sellerBalanceBefore + totalPrice, seller.balance);
        assertEq(buyerBalanceBefore - totalPrice, msgSender.balance);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address listingSeller, uint96 listingPrice) = page.listings(id);

            assertEq(address(0), listingSeller);
            assertEq(0, listingPrice);
            assertEq(msgSender, page.ownerOf(id));
            assertEq(address(page), collection.ownerOf(id));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchBuyPartial(uint8 listQuantity) external {
        vm.assume(listQuantity != 0);

        // Set `msgSender` to an EOA to avoid reversions from contract accounts w/o fallback methods
        address msgSender = accounts[0];

        // Set `seller` to this address to avoid reversions from contract accounts w/o fallback methods
        address seller = address(this);

        // Index of the listing to cancel to test partial buy fill
        uint256 canceledIndex = 0;

        (uint256[] memory ids, uint96[] memory prices) = _batchMintDepositList(
            seller,
            listQuantity
        );
        uint256 totalPrice;

        for (uint256 i = 0; i < ids.length; ) {
            totalPrice += uint256(prices[i]);

            unchecked {
                ++i;
            }
        }

        vm.prank(seller);

        page.cancel(ids[canceledIndex]);

        vm.deal(msgSender, totalPrice);

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = msgSender.balance;
        uint256 expectedRefund = prices[canceledIndex];

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchBuy(ids);

        // Send enough ETH to cover seller proceeds
        page.batchBuy{value: totalPrice}(ids);

        // Seller should not receive ETH for canceled listing
        assertEq(
            (sellerBalanceBefore + totalPrice) - expectedRefund,
            seller.balance
        );

        // Buyer should have received a refund for the unfilled listing(s)
        assertEq(
            (buyerBalanceBefore - totalPrice) + expectedRefund,
            msgSender.balance
        );

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address listingSeller, uint96 listingPrice) = page.listings(id);

            assertEq(address(0), listingSeller);
            assertEq(0, listingPrice);
            assertEq(address(page), collection.ownerOf(id));

            if (i == canceledIndex) {
                assertEq(seller, page.ownerOf(id));
            } else {
                assertEq(msgSender, page.ownerOf(id));
            }

            unchecked {
                ++i;
            }
        }
    }
}
