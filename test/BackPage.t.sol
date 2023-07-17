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

    event Initialize();
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event BatchTransfer(address indexed from, address[] to, uint256[] ids);
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event Deposit(address indexed depositor, uint256 indexed id);
    event Withdraw(address indexed withdrawer, uint256 indexed id);
    event List(address indexed seller, uint256 indexed id, uint96 price);
    event Edit(address indexed seller, uint256 indexed id, uint96 price);
    event Cancel(address indexed seller, uint256 indexed id);
    event BatchDeposit(address indexed depositor, uint256[] ids);
    event BatchWithdraw(address indexed withdrawer, uint256[] ids);
    event BatchList(address indexed seller, uint256[] ids, uint96[] prices);
    event BatchEdit(address indexed seller, uint256[] ids, uint96[] prices);
    event BatchCancel(address indexed seller, uint256[] ids);
    event Buy(address indexed buyer, uint256 indexed id);
    event BatchBuy(address indexed buyer, uint256[] ids);
    event MakeOffer(address indexed maker, uint256 offer, uint256 quantity);
    event CancelOffer(address indexed maker, uint256 offer, uint256 quantity);
    event TakeOffer(
        address indexed taker,
        uint256[] ids,
        address indexed maker,
        uint256 offer
    );

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
        page.deposit(id);

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

        emit List(to, id, price);

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
        address msgSender = address(this);
        address operator = accounts[0];
        bool approved = true;

        assertFalse(page.isApprovedForAll(msgSender, operator));

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(page));

        emit ApprovalForAll(msgSender, operator, approved);

        page.setApprovalForAll(operator, approved);

        assertTrue(page.isApprovedForAll(msgSender, operator));
    }

    function testSetApprovalForAllTrueToFalse() external {
        address msgSender = address(this);
        address operator = accounts[0];
        bool approvedTrue = true;

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(page));

        emit ApprovalForAll(msgSender, operator, approvedTrue);

        page.setApprovalForAll(operator, approvedTrue);

        assertTrue(page.isApprovedForAll(msgSender, operator));

        bool approvedFalse = false;

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(page));

        emit ApprovalForAll(msgSender, operator, approvedFalse);

        page.setApprovalForAll(operator, approvedFalse);

        assertFalse(page.isApprovedForAll(msgSender, operator));
    }

    function testSetApprovalForAllFuzz(
        address msgSender,
        address operator,
        bool approved
    ) external {
        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(page));

        emit ApprovalForAll(msgSender, operator, approved);

        page.setApprovalForAll(operator, approved);

        assertEq(approved, page.isApprovedForAll(msgSender, operator));
    }

    /*//////////////////////////////////////////////////////////////
                             transferFrom
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferFromNotOwner() external {
        address msgSender = address(this);
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        assertEq(address(0), page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.transferFrom(from, to, id);
    }

    function testCannotTransferFromUnsafeRecipient() external {
        address msgSender = address(this);
        address from = accounts[0];
        address to = address(0);
        uint256 id = 1;

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(Page.UnsafeRecipient.selector);

        page.transferFrom(from, to, id);
    }

    function testCannotTransferFromNotAuthorized() external {
        address msgSender = address(this);
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));
        assertFalse(page.isApprovedForAll(from, msgSender));

        vm.prank(msgSender);
        vm.expectRevert(Page.NotApproved.selector);

        page.transferFrom(from, to, id);
    }

    function testTransferFromSelf() external {
        address msgSender = address(this);
        address from = address(this);
        address to = accounts[1];
        uint256 id = 1;

        _mintDeposit(from, id);

        assertEq(msgSender, from);
        assertEq(from, page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(page));

        emit Transfer(from, to, id);

        page.transferFrom(from, to, id);

        assertEq(to, page.ownerOf(id));
    }

    function testTransferFrom() external {
        address msgSender = address(this);
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));

        vm.prank(from);

        page.setApprovalForAll(msgSender, true);

        assertTrue(page.isApprovedForAll(from, msgSender));
        assertTrue(msgSender != from);

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(page));

        emit Transfer(from, to, id);

        page.transferFrom(from, to, id);

        assertEq(to, page.ownerOf(id));
    }

    function testTransferFromFuzz(
        address from,
        address to,
        uint256 id,
        bool selfTransfer
    ) external {
        vm.assume(from != address(0));
        vm.assume(from != to);

        _mintDeposit(from, id);

        assertEq(from, page.ownerOf(id));

        address msgSender = from;

        if (!selfTransfer) {
            msgSender = address(this);

            vm.prank(from);

            page.setApprovalForAll(msgSender, true);

            assertTrue(page.isApprovedForAll(from, msgSender));
            assertTrue(msgSender != from);
        }

        bool toIsUnsafe = to == address(0);

        vm.prank(msgSender);

        if (toIsUnsafe) {
            vm.expectRevert(Page.UnsafeRecipient.selector);
        } else {
            vm.expectEmit(true, true, true, true, address(page));

            emit Transfer(from, to, id);
        }

        page.transferFrom(from, to, id);

        if (!toIsUnsafe) {
            assertEq(to, page.ownerOf(id));
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchTransferFrom
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchTransferFromNotAuthorized() external {
        address msgSender = address(this);
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        assertFalse(page.isApprovedForAll(from, msgSender));
        assertTrue(from != msgSender);

        vm.prank(msgSender);
        vm.expectRevert(Page.NotApproved.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromNotOwnerSelf() external {
        address msgSender = address(this);
        address from = address(this);
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        assertEq(msgSender, from);

        for (uint256 i = 0; i < ids.length; ) {
            assertTrue(from != page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(msgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromNotOwner() external {
        address msgSender = address(this);
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            assertTrue(msgSender != page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);

        page.setApprovalForAll(msgSender, true);

        assertTrue(page.isApprovedForAll(from, msgSender));

        vm.prank(msgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromUnsafeRecipientSelf() external {
        address msgSender = address(this);
        address from = address(this);
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = address(0);
        ids[0] = 1;

        assertEq(msgSender, from);

        for (uint256 i = 0; i < ids.length; ) {
            _mintDeposit(from, ids[i]);

            assertEq(from, page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(msgSender);
        vm.expectRevert(Page.UnsafeRecipient.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromUnsafeRecipient() external {
        address msgSender = address(this);
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

        page.setApprovalForAll(msgSender, true);

        assertTrue(page.isApprovedForAll(from, msgSender));

        vm.prank(msgSender);
        vm.expectRevert(Page.UnsafeRecipient.selector);

        page.batchTransferFrom(from, to, ids);
    }

    function testBatchTransferFromSelf() external {
        address msgSender = address(this);
        address from = address(this);
        address[] memory to = new address[](accounts.length);
        uint256[] memory ids = new uint256[](accounts.length);

        assertEq(msgSender, from);

        for (uint256 i = 0; i < accounts.length; ) {
            to[i] = accounts[i];
            ids[i] = i;

            _mintDeposit(from, ids[i]);

            assertEq(from, page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchTransfer(from, to, ids);

        page.batchTransferFrom(from, to, ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(to[i], page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchTransferFrom() external {
        address msgSender = address(this);
        address from = accounts[0];
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

        page.setApprovalForAll(msgSender, true);

        assertTrue(page.isApprovedForAll(from, msgSender));

        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchTransfer(from, to, ids);

        page.batchTransferFrom(from, to, ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(to[i], page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    // /*//////////////////////////////////////////////////////////////
    //                          deposit
    // //////////////////////////////////////////////////////////////*/

    function testDeposit() external {
        address msgSender = address(this);
        uint256 id = 0;

        collection.mint(msgSender, id);
        collection.setApprovalForAll(address(page), true);

        // Page must be approved to transfer tokens on behalf of the sender
        assertTrue(collection.isApprovedForAll(msgSender, address(page)));

        // Pre-deposit state
        assertEq(msgSender, collection.ownerOf(id));
        assertEq(address(0), page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(page));

        emit Deposit(msgSender, id);

        page.deposit(id);

        // Post-deposit state
        assertEq(msgSender, page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             batchDeposit
    //////////////////////////////////////////////////////////////*/

    function testBatchDeposit() external {
        uint256 quantity = 5;
        uint256[] memory ids = new uint256[](quantity);
        address msgSender = address(this);

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

        vm.expectEmit(true, true, false, true, address(page));

        emit BatchDeposit(msgSender, ids);

        page.batchDeposit(ids);

        vm.stopPrank();

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(msgSender, page.ownerOf(ids[i]));
            assertEq(address(page), collection.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             withdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotWithdrawMsgSenderNotOwner() external {
        address owner = address(this);
        address msgSender = accounts[0];
        uint256 id = 0;

        _mintDeposit(owner, id);

        assertTrue(msgSender != page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.withdraw(id);
    }

    function testWithdraw() external {
        address msgSender = address(this);
        uint256 id = 0;

        _mintDeposit(msgSender, id);

        assertEq(msgSender, page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(page));

        emit Withdraw(msgSender, id);

        page.withdraw(id);

        assertEq(address(0), page.ownerOf(id));
        assertEq(msgSender, collection.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             batchWithdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchWithdrawMsgSenderNotOwner() external {
        address owner = address(this);
        address unauthorizedMsgSender = accounts[0];
        uint256 mintQuantity = 5;
        uint256[] memory ids = _batchMintDeposit(owner, mintQuantity);

        for (uint256 i = 0; i < ids.length; ) {
            assertTrue(unauthorizedMsgSender != page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.batchWithdraw(ids);
    }

    function testBatchWithdraw() external {
        address msgSender = address(this);
        uint256 mintQuantity = 5;
        uint256[] memory ids = _batchMintDeposit(msgSender, mintQuantity);

        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchWithdraw(msgSender, ids);

        page.batchWithdraw(ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(0), page.ownerOf(ids[i]));
            assertEq(msgSender, collection.ownerOf(ids[i]));

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
        vm.expectEmit(true, true, false, true, address(page));

        emit List(msgSender, id, price);

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
        vm.expectEmit(true, true, false, true, address(page));

        emit Edit(msgSender, id, newPrice);

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
        vm.expectEmit(true, true, false, true, address(page));

        emit Cancel(msgSender, id);

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
        vm.expectEmit(true, true, false, true, address(page));

        emit Buy(msgSender, id);

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
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchList(msgSender, ids, prices);

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
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchEdit(msgSender, ids, newPrices);

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
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchCancel(msgSender, ids);

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
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchBuy(msgSender, ids);

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
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchBuy(msgSender, ids);

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

    /*//////////////////////////////////////////////////////////////
                             onERC721Received
    //////////////////////////////////////////////////////////////*/

    function testCannotOnERC721ReceivedNotCollection(
        address msgSender,
        uint256 id
    ) external {
        vm.assume(msgSender != address(0));
        vm.assume(msgSender != address(collection));

        collection.mint(msgSender, id);

        assertTrue(msgSender != address(collection));

        vm.prank(msgSender);
        vm.expectRevert(Page.NotCollection.selector);

        page.onERC721Received(address(0), msgSender, id, "");
    }

    function testCannotOnERC721ReceivedInvalidAddress(uint256 id) external {
        address msgSender = address(page.collection());

        vm.prank(msgSender);
        vm.expectRevert(Page.InvalidAddress.selector);

        page.onERC721Received(address(0), address(0), id, "");
    }

    function testOnERC721Received(address msgSender, uint256 id) external {
        vm.assume(msgSender != address(0));

        collection.mint(msgSender, id);

        assertEq(address(0), page.ownerOf(id));
        assertEq(msgSender, collection.ownerOf(id));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(msgSender, address(page), id);

        collection.safeTransferFrom(msgSender, address(page), id);

        assertEq(msgSender, page.ownerOf(id));
        assertEq(address(page), collection.ownerOf(id));
    }
}
