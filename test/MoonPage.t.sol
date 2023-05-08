// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {MoonBook} from "src/MoonBook.sol";
import {MoonPage} from "src/MoonPage.sol";

contract MoonPageTest is Test, ERC721TokenReceiver {
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    MoonBook private immutable book;
    MoonPage private immutable page;

    uint256[] private ids = [1, 39, 111];
    address[] private accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
    event List(uint256 indexed id, address indexed seller, uint96 price);
    event Edit(uint256 indexed id, address indexed seller, uint96 newPrice);
    event Cancel(uint256 indexed id, address indexed seller);
    event Buy(
        uint256 indexed id,
        address indexed buyer,
        address indexed seller,
        uint96 price
    );

    constructor() {
        book = new MoonBook();
        page = MoonPage(book.createPage(LLAMA));

        // Verify that page cannot be initialized again
        vm.expectRevert("Initializable: contract is already initialized");

        page.initialize(address(this), LLAMA);
    }

    function setUp() external {
        for (uint256 i; i < ids.length; ) {
            address originalOwner = LLAMA.ownerOf(ids[i]);

            vm.prank(originalOwner);

            LLAMA.safeTransferFrom(originalOwner, address(this), ids[i]);

            unchecked {
                ++i;
            }
        }

        LLAMA.setApprovalForAll(address(page), true);
    }

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositRecipientZero() external {
        address recipient = address(0);

        vm.expectRevert(MoonPage.Zero.selector);

        page.deposit(ids[0], recipient);
    }

    function testDeposit() external {
        uint256 id;
        address recipient;
        uint256 iLen = ids.length;

        for (uint256 i; i < iLen; ) {
            id = ids[i];
            recipient = accounts[i];

            assertEq(address(this), LLAMA.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.expectEmit(true, true, true, true, address(page));

            emit TransferSingle(address(this), address(0), recipient, id, 1);

            page.deposit(id, recipient);

            assertEq(address(page), LLAMA.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             withdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotWithdrawRecipientZero() external {
        address recipient = address(0);

        vm.expectRevert(MoonPage.Zero.selector);

        page.withdraw(ids[0], recipient);
    }

    function testCannotWithdrawMsgSenderInvalid() external {
        address msgSender = accounts[0];
        uint256 id = ids[0];
        address recipient = accounts[0];

        vm.prank(msgSender);
        vm.expectRevert(MoonPage.Invalid.selector);

        page.withdraw(id, recipient);
    }

    function testWithdraw() external {
        uint256 id;
        address recipient;
        uint256 iLen = ids.length;

        // Deposit the NFTs and mint derivative tokens for recipients
        for (uint256 i; i < iLen; ) {
            id = ids[i];
            recipient = accounts[i];

            page.deposit(id, recipient);

            unchecked {
                ++i;
            }
        }

        address owner;

        // Withdraw the NFTs by redeeming the derivative tokens as their owners
        for (uint256 i; i < iLen; ) {
            id = ids[i];
            owner = accounts[i];

            vm.prank(owner);
            vm.expectEmit(true, true, true, true, address(page));

            emit TransferSingle(owner, owner, address(0), id, 1);

            page.withdraw(id, recipient);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             list
    //////////////////////////////////////////////////////////////*/

    function testCannotListUnauthorized() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint96 price = 1 ether;

        // Mint a derivative token for a recipient and attempt to list on their behalf
        page.deposit(id, recipient);

        assertEq(recipient, page.ownerOf(id));
        assertEq(1, page.balanceOf(recipient, id));

        vm.expectRevert(MoonPage.Unauthorized.selector);

        page.list(id, price);
    }

    function testCannotListPriceZero() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint96 price = 0;

        // Mint a derivative token for a recipient and attempt to list on their behalf
        page.deposit(id, recipient);

        assertEq(recipient, page.ownerOf(id));
        assertEq(1, page.balanceOf(recipient, id));

        // Call `list` as the recipient to ensure that they are authorized to sell
        vm.prank(recipient);
        vm.expectRevert(MoonPage.Zero.selector);

        page.list(id, price);
    }

    function testList(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        uint256 iLen = ids.length;

        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint96 price = 0.1 ether * uint96(priceMultiplier);

            page.deposit(id, recipient);

            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));
            assertEq(0, page.balanceOf(address(page), id));

            vm.prank(recipient);
            vm.expectEmit(true, true, false, true, address(page));

            emit List(id, recipient, price);

            page.list(id, price);

            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(recipient, seller);
            assertEq(price, listingPrice);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             edit
    //////////////////////////////////////////////////////////////*/

    function testCannotEditPriceZero() external {
        uint256 id = ids[0];
        uint96 price = 0;

        vm.expectRevert(MoonPage.Zero.selector);

        page.edit(id, price);
    }

    function testCannotEditUnauthorized() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint96 price = 1 ether;
        uint96 newPrice = 2 ether;

        page.deposit(id, recipient);

        vm.prank(recipient);

        page.list(id, price);

        (address seller, ) = page.listings(id);

        assertEq(recipient, seller);

        vm.expectRevert(MoonPage.Unauthorized.selector);

        page.edit(id, newPrice);
    }

    function testEdit(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        uint256 iLen = ids.length;

        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint96 price = 0.1 ether * uint96(priceMultiplier);
            uint96 newPrice = 0.2 ether * uint96(priceMultiplier);

            assertTrue(price != newPrice);

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price);

            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(recipient, seller);
            assertEq(price, listingPrice);

            vm.prank(recipient);
            vm.expectEmit(true, true, false, true, address(page));

            emit Edit(id, recipient, newPrice);

            page.edit(id, newPrice);

            (seller, listingPrice) = page.listings(id);

            // Verify that the updated listing has the same seller, different price
            assertEq(recipient, seller);
            assertEq(newPrice, listingPrice);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             cancel
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelUnauthorized() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint96 price = 1 ether;

        page.deposit(id, recipient);

        vm.prank(recipient);

        page.list(id, price);

        (address seller, ) = page.listings(id);

        assertEq(recipient, seller);

        vm.expectRevert(MoonPage.Unauthorized.selector);

        page.cancel(id);
    }

    function testCancel(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        uint256 iLen = ids.length;

        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint96 price = 0.1 ether * uint96(priceMultiplier);

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price);

            assertEq(address(page), page.ownerOf(id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.prank(recipient);
            vm.expectEmit(true, true, false, true, address(page));

            emit Cancel(id, recipient);

            page.cancel(id);

            assertEq(recipient, page.ownerOf(id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(1, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             buy
    //////////////////////////////////////////////////////////////*/

    function testCannotBuyMsgValueZero() external {
        uint256 id = ids[0];
        uint256 msgValue = 0;

        vm.expectRevert(MoonPage.Zero.selector);

        page.buy{value: msgValue}(id);
    }

    function testCannotBuyMsgValueInsufficient(bool shouldList) external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint96 price = 1 ether;

        // Reverts with `Insufficient` if msg.value is insufficient or if not listed
        if (shouldList) {
            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price);
        }

        vm.expectRevert(MoonPage.Insufficient.selector);

        // Attempt to buy with msg.value less than price
        page.buy{value: price - 1}(id);
    }

    function testBuy(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        uint256 iLen = ids.length;

        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint96 price = 0.1 ether * uint96(priceMultiplier);

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price);

            (address seller, uint96 listingPrice) = page.listings(id);
            uint256 buyerBalanceBefore = address(this).balance;
            uint256 sellerBalanceBefore = recipient.balance;

            assertEq(recipient, seller);
            assertEq(price, listingPrice);
            assertEq(address(page), page.ownerOf(id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(0, page.balanceOf(address(this), id));

            vm.expectEmit(true, true, true, true, address(page));

            emit Buy(id, address(this), seller, price);

            page.buy{value: price}(id);

            (seller, listingPrice) = page.listings(id);

            assertEq(address(0), seller);
            assertEq(0, listingPrice);
            assertEq(address(this), page.ownerOf(id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(1, page.balanceOf(address(this), id));
            assertEq(buyerBalanceBefore - price, address(this).balance);
            assertEq(sellerBalanceBefore + price, recipient.balance);

            unchecked {
                ++i;
            }
        }
    }
}
