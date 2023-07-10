// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {BackPage} from "src/backPage/BackPage.sol";
import {Page} from "src/Page.sol";
import {BackPageBase} from "test/backPage/BackPageBase.sol";

contract BackPageExchangeTest is Test, BackPageBase {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );
    event List(uint256 id);
    event Edit(uint256 id);
    event Cancel(uint256 id);
    event Buy(uint256 id);
    event BatchList(uint256[] ids);
    event BatchEdit(uint256[] ids);
    event BatchCancel(uint256[] ids);
    event BatchBuy(uint256[] ids);

    /*//////////////////////////////////////////////////////////////
                             tokenURI
    //////////////////////////////////////////////////////////////*/

    function testTokenURI() external {
        uint256 id = ids[0];
        string memory collectionURI = LLAMA.tokenURI(id);

        assertEq(
            keccak256(abi.encodePacked(collectionURI)),
            keccak256(abi.encodePacked(page.tokenURI(id)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testDeposit() external {
        uint256 id;
        address recipient;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            recipient = accounts[i];

            assertEq(address(this), LLAMA.ownerOf(id));
            assertEq(address(0), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.expectEmit(true, true, true, true, address(LLAMA));

            emit Transfer(address(this), address(page), id);

            page.deposit(id, recipient);

            assertEq(address(page), LLAMA.ownerOf(id));
            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchDeposit
    //////////////////////////////////////////////////////////////*/

    function testBatchDeposit() external {
        address recipient = accounts[0];
        uint256[] memory amounts = new uint256[](ids.length);

        // For batching the balance check
        address[] memory batchBalanceRecipient = new address[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            batchBalanceRecipient[i] = recipient;
            amounts[i] = ONE;

            unchecked {
                ++i;
            }
        }

        page.batchDeposit(ids, recipient);

        uint256[] memory balances = page.balanceOfBatch(
            batchBalanceRecipient,
            ids
        );

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];

            assertEq(1, balances[i]);
            assertEq(recipient, page.ownerOf(id));
            assertEq(address(page), LLAMA.ownerOf(id));

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

        page.deposit(ids[0], accounts[0]);

        vm.prank(accounts[0]);
        vm.expectRevert();

        page.withdraw(ids[0], recipient);
    }

    function testCannotWithdrawMsgSenderUnauthorized() external {
        address msgSender = accounts[0];
        uint256 id = ids[0];
        address recipient = accounts[0];

        vm.prank(msgSender);
        vm.expectRevert(Page.Unauthorized.selector);

        page.withdraw(id, recipient);
    }

    function testWithdraw() external {
        uint256 id;
        address recipient;

        // Deposit the NFTs and mint derivative tokens for recipients
        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            recipient = accounts[i];

            page.deposit(id, recipient);

            assertEq(address(page), LLAMA.ownerOf(id));
            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }

        address owner;

        // Withdraw the NFTs by redeeming the derivative tokens as their owners
        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            owner = accounts[i];

            vm.prank(owner);
            vm.expectEmit(true, true, true, true, address(LLAMA));

            emit Transfer(address(page), recipient, id);

            page.withdraw(id, recipient);

            assertEq(recipient, LLAMA.ownerOf(id));
            assertEq(address(0), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchWithdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchWithdrawRecipientZero() external {
        uint256[] memory withdrawIds = new uint256[](1);
        address recipient = address(0);

        page.batchDeposit(ids, accounts[0]);

        vm.prank(accounts[0]);
        vm.expectRevert();

        page.batchWithdraw(withdrawIds, recipient);
    }

    function testCannotBatchWithdrawMsgSenderUnauthorized() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        vm.prank(address(this));
        vm.expectRevert(Page.Unauthorized.selector);

        page.batchWithdraw(ids, address(this));
    }

    function testBatchWithdraw() external {
        address recipient = accounts[0];
        uint256[] memory amounts = new uint256[](ids.length);

        // For batching the balance check
        address[] memory batchBalanceRecipient = new address[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            batchBalanceRecipient[i] = recipient;
            amounts[i] = ONE;

            unchecked {
                ++i;
            }
        }

        page.batchDeposit(ids, recipient);

        uint256[] memory balances = page.balanceOfBatch(
            batchBalanceRecipient,
            ids
        );

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];

            assertEq(1, balances[i]);
            assertEq(recipient, page.ownerOf(id));
            assertEq(address(page), LLAMA.ownerOf(id));

            unchecked {
                ++i;
            }
        }

        address withdrawRecipient = address(this);

        vm.prank(recipient);

        page.batchWithdraw(ids, withdrawRecipient);

        balances = page.balanceOfBatch(batchBalanceRecipient, ids);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];

            assertEq(0, balances[i]);
            assertEq(address(0), page.ownerOf(id));
            assertEq(withdrawRecipient, LLAMA.ownerOf(id));

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

        vm.expectRevert(Page.Unauthorized.selector);

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
        vm.expectRevert(Page.Invalid.selector);

        page.list(id, price);
    }

    function testList(uint96 price) external {
        vm.assume(price != 0);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];

            page.deposit(id, recipient);

            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));
            assertEq(0, page.balanceOf(address(page), id));

            vm.prank(recipient);
            vm.expectEmit(false, false, false, true, address(page));

            emit List(id);

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

        vm.expectRevert(Page.Invalid.selector);

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

        vm.expectRevert(Page.Unauthorized.selector);

        page.edit(id, newPrice);
    }

    function testEdit(uint96 price, uint96 newPrice) external {
        vm.assume(price != 0);
        vm.assume(newPrice != 0);
        vm.assume(newPrice != price);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price);

            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(recipient, seller);
            assertEq(price, listingPrice);

            vm.prank(recipient);
            vm.expectEmit(false, false, false, true, address(page));

            emit Edit(id);

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

        vm.expectRevert(Page.Unauthorized.selector);

        page.cancel(id);
    }

    function testCancel() external {
        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint96 price = 1 ether;

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price);

            assertEq(address(page), page.ownerOf(id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.prank(recipient);
            vm.expectEmit(false, false, false, true, address(page));

            emit Cancel(id);

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

    function testCannotBuyMsgValueInsufficient(bool shouldList) external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint96 price = 1 ether;

        // Reverts with `Insufficient` if msg.value is insufficient or if not listed
        if (shouldList) {
            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price);

            vm.expectRevert(Page.Insufficient.selector);
        } else {
            vm.expectRevert(Page.Invalid.selector);
        }

        // Attempt to buy with msg.value less than price
        page.buy{value: price - 1}(id);
    }

    function testBuy(uint96 price) external {
        vm.assume(price != 0);

        uint256 id;
        address recipient;
        address seller;
        uint96 listingPrice;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            recipient = accounts[i];

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price);

            (seller, listingPrice) = page.listings(id);

            assertEq(price, listingPrice);

            uint256 sellerBalanceBefore = recipient.balance;

            vm.deal(address(this), listingPrice);
            vm.expectEmit(false, false, false, true, address(page));

            emit Buy(id);

            page.buy{value: listingPrice}(id);

            (seller, listingPrice) = page.listings(id);

            assertEq(address(0), seller);
            assertEq(0, listingPrice);
            assertEq(address(this), page.ownerOf(id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(1, page.balanceOf(address(this), id));
            assertEq(sellerBalanceBefore + price, recipient.balance);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchList
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchListMismatchedArrayInvalid() external {
        uint96[] memory prices = new uint96[](0);

        assertTrue(ids.length != prices.length);

        vm.expectRevert(stdError.indexOOBError);

        page.batchList(ids, prices);
    }

    function testBatchList(uint96 price) external {
        vm.assume(price != 0);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = price;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchList(ids);

        page.batchList(ids, prices);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(recipient, seller);
            assertEq(prices[i], listingPrice);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchEdit
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchEditMismatchedArrayInvalid() external {
        uint96[] memory newPrices = new uint96[](0);

        vm.expectRevert(stdError.indexOOBError);

        page.batchEdit(ids, newPrices);
    }

    function testCannotBatchEditNewPriceZero() external {
        uint96[] memory newPrices = new uint96[](ids.length);

        vm.expectRevert(Page.Invalid.selector);

        page.batchEdit(ids, newPrices);
    }

    function testCannotBatchEditUnauthorized() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint96[] memory prices = new uint96[](ids.length);
        uint96[] memory newPrices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = 1 ether;
            newPrices[i] = 2 ether;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices);

        vm.expectRevert(Page.Unauthorized.selector);

        page.batchEdit(ids, newPrices);
    }

    function testBatchEdit(uint96 price, uint96 newPrice) external {
        vm.assume(price != 0);
        vm.assume(newPrice != 0);
        vm.assume(newPrice != price);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint96[] memory prices = new uint96[](ids.length);
        uint96[] memory newPrices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = price;
            newPrices[i] = newPrice;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices);

        vm.prank(recipient);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchEdit(ids);

        page.batchEdit(ids, newPrices);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(recipient, seller);
            assertEq(newPrices[i], listingPrice);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchCancel
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchCancelUnauthorized() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = 1 ether;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices);

        vm.expectRevert(Page.Unauthorized.selector);

        page.batchCancel(ids);
    }

    function testBatchCancel() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = 1 ether;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices);

        vm.prank(recipient);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchCancel(ids);

        page.batchCancel(ids);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(address(0), seller);
            assertEq(0, listingPrice);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchBuy
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchBuyMsgValueInsufficient() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = 1 ether;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices);

        uint256 totalSellerProceeds;

        for (uint256 i = 0; i < ids.length; ) {
            totalSellerProceeds += prices[i];

            unchecked {
                ++i;
            }
        }

        // Deal ETH to the Page contract to mock ETH from offers
        vm.deal(address(page), 1 ether);

        assertEq(address(page).balance, 1 ether);

        vm.deal(address(this), totalSellerProceeds);
        vm.expectRevert(stdError.arithmeticError);

        // Send an insufficient amount of ETH
        page.batchBuy{value: totalSellerProceeds - 1}(ids);

        // Balance should be unchanged
        assertEq(address(page).balance, 1 ether);
    }

    function testBatchBuy(uint96 price) external {
        vm.assume(price != 0);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = price;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices);

        uint256 totalPriceETH;
        uint256 sellerBalanceBefore = recipient.balance;

        for (uint256 i = 0; i < ids.length; ) {
            totalPriceETH += prices[i];

            unchecked {
                ++i;
            }
        }

        vm.deal(address(this), totalPriceETH);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchBuy(ids);

        // Send enough ETH to cover seller proceeds but not tips
        page.batchBuy{value: totalPriceETH}(ids);

        assertEq(sellerBalanceBefore + totalPriceETH, recipient.balance);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(this), page.ownerOf(ids[i]));
            assertEq(1, page.balanceOf(address(this), ids[i]));
            assertEq(0, page.balanceOf(address(page), ids[i]));
            assertEq(0, page.balanceOf(recipient, ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchBuyPartial(uint96 price) external {
        vm.assume(price != 0);

        address recipient = accounts[0];

        // Listing id index - will be canceled before the buy, resulting
        // in only a partial buy
        uint256 cancelIndex = 1;

        page.batchDeposit(ids, recipient);

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = price;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices);

        uint256 totalPriceETH = price * ids.length;

        // Since 1 listing will be canceled, the expected refund is its price
        uint256 expectedETHRefund = price;

        uint256 sellerBalanceBefore = recipient.balance;

        vm.prank(recipient);

        page.cancel(ids[cancelIndex]);

        vm.deal(address(this), totalPriceETH);

        uint256 buyerBalanceBefore = address(this).balance;

        vm.expectEmit(false, false, false, true, address(page));

        emit BatchBuy(ids);

        // Send enough ETH to cover seller proceeds but not tips
        page.batchBuy{value: totalPriceETH}(ids);

        assertEq(
            sellerBalanceBefore + totalPriceETH - expectedETHRefund,
            recipient.balance
        );
        assertEq(
            buyerBalanceBefore - totalPriceETH + expectedETHRefund,
            address(this).balance
        );

        for (uint256 i = 0; i < ids.length; ) {
            if (i == cancelIndex) {
                ++i;
                continue;
            }

            assertEq(address(this), page.ownerOf(ids[i]));
            assertEq(1, page.balanceOf(address(this), ids[i]));
            assertEq(0, page.balanceOf(address(page), ids[i]));
            assertEq(0, page.balanceOf(recipient, ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
