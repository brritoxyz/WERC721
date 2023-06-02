// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {FrontPage} from "src/FrontPage.sol";
import {FrontPageBase} from "test/FrontPageBase.sol";

contract FrontPageExchangeTest is Test, FrontPageBase {
    uint256 internal constant ONE = 1;

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
    event SetTipRecipient(address tipRecipient);
    event List(uint256 id);
    event Edit(uint256 id);
    event Cancel(uint256 id);
    event Buy(uint256 id);
    event BatchList(uint256[] ids);
    event BatchEdit(uint256[] ids);
    event BatchCancel(uint256[] ids);
    event BatchBuy(uint256[] ids);

    /*//////////////////////////////////////////////////////////////
                             list
    //////////////////////////////////////////////////////////////*/

    function testCannotListUnauthorized() external {
        uint256 id = ids[0];
        uint96 price = 1 ether;
        address notOwner = address(1);

        assertTrue(notOwner != page.ownerOf(id));

        // Attempt to list as an account that does not own the token
        vm.prank(notOwner);
        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.list(id, price);
    }

    function testCannotListPriceZero() external {
        uint256 id = ids[0];
        uint96 price = 0;

        assertEq(address(this), page.ownerOf(id));
        assertEq(1, page.balanceOf(address(this), id));

        vm.expectRevert(FrontPage.Invalid.selector);

        page.list(id, price);
    }

    function testList(uint96 price) external {
        vm.assume(price != 0);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];

            assertEq(address(this), page.ownerOf(id));
            assertEq(1, page.balanceOf(address(this), id));
            assertEq(0, page.balanceOf(address(page), id));

            vm.expectEmit(false, false, false, true, address(page));

            emit List(id);

            page.list(id, price);

            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(address(this), id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(address(this), seller);
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

        vm.expectRevert(FrontPage.Invalid.selector);

        page.edit(id, price);
    }

    function testCannotEditUnauthorized() external {
        uint256 id = ids[0];
        uint96 price = 1 ether;
        uint96 newPrice = 2 ether;

        page.list(id, price);

        address notOwner = address(1);
        (address listingSeller, uint96 listingPrice) = page.listings(id);

        assertTrue(notOwner != listingSeller);
        assertEq(price, listingPrice);

        vm.prank(notOwner);
        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.edit(id, newPrice);
    }

    function testEdit(uint96 price, uint96 newPrice) external {
        vm.assume(price != 0);
        vm.assume(newPrice != 0);
        vm.assume(newPrice != price);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];

            page.list(id, price);

            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(this), seller);
            assertEq(price, listingPrice);

            vm.expectEmit(false, false, false, true, address(page));

            emit Edit(id);

            page.edit(id, newPrice);

            (seller, listingPrice) = page.listings(id);

            // Verify that the updated listing has the same seller, different price
            assertEq(address(this), seller);
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
        uint96 price = 1 ether;

        page.list(id, price);

        address notOwner = address(1);
        (address listingSeller, uint96 listingPrice) = page.listings(id);

        assertTrue(notOwner != listingSeller);
        assertEq(price, listingPrice);

        vm.prank(notOwner);
        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.cancel(id);
    }

    function testCancel() external {
        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            uint96 price = 1 ether;

            page.list(id, price);

            assertEq(address(page), page.ownerOf(id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(0, page.balanceOf(address(this), id));

            vm.expectEmit(false, false, false, true, address(page));

            emit Cancel(id);

            page.cancel(id);

            assertEq(address(this), page.ownerOf(id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(1, page.balanceOf(address(this), id));

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
        uint96 price = 1 ether;

        // Reverts with `Insufficient` if msg.value is insufficient or if not listed
        if (shouldList) {
            page.list(id, price);

            vm.expectRevert(FrontPage.InvalidMsgValue.selector);
        } else {
            vm.expectRevert(FrontPage.Invalid.selector);
        }

        // Attempt to buy with msg.value less than price
        page.buy{value: price - 1}(id);
    }

    function testBuy(uint96 price) external {
        vm.assume(price != 0);

        uint256 id;
        address buyer = address(1);

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];

            page.list(id, price);

            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(this), seller);
            assertEq(price, listingPrice);

            uint256 sellerBalanceBefore = address(this).balance;

            vm.deal(buyer, listingPrice);

            uint256 buyerBalanceBefore = buyer.balance;

            vm.prank(buyer);
            vm.expectEmit(false, false, false, true, address(page));

            emit Buy(id);

            page.buy{value: listingPrice}(id);

            (seller, listingPrice) = page.listings(id);

            assertEq(address(0), seller);
            assertEq(0, listingPrice);
            assertEq(buyer, page.ownerOf(id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(1, page.balanceOf(buyer, id));
            assertEq(sellerBalanceBefore + price, address(this).balance);
            assertEq(buyerBalanceBefore - price, buyer.balance);

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

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = price;

            unchecked {
                ++i;
            }
        }

        vm.expectEmit(false, false, false, true, address(page));

        emit BatchList(ids);

        page.batchList(ids, prices);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(address(this), id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(address(this), seller);
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

        vm.expectRevert(FrontPage.Invalid.selector);

        page.batchEdit(ids, newPrices);
    }

    function testCannotBatchEditUnauthorized() external {
        uint96[] memory prices = new uint96[](ids.length);
        uint96[] memory newPrices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = 1 ether;
            newPrices[i] = 2 ether;

            unchecked {
                ++i;
            }
        }

        page.batchList(ids, prices);

        // Zero address guaranteed to not be the listing seller
        vm.prank(address(0));

        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.batchEdit(ids, newPrices);
    }

    function testBatchEdit(uint96 price, uint96 newPrice) external {
        vm.assume(price != 0);
        vm.assume(newPrice != 0);
        vm.assume(newPrice != price);

        uint96[] memory prices = new uint96[](ids.length);
        uint96[] memory newPrices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = price;
            newPrices[i] = newPrice;

            unchecked {
                ++i;
            }
        }

        page.batchList(ids, prices);

        vm.expectEmit(false, false, false, true, address(page));

        emit BatchEdit(ids);

        page.batchEdit(ids, newPrices);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(address(this), id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(address(this), seller);
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
        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = 1 ether;

            unchecked {
                ++i;
            }
        }

        page.batchList(ids, prices);

        vm.prank(address(0));
        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.batchCancel(ids);
    }

    function testBatchCancel() external {
        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = 1 ether;

            unchecked {
                ++i;
            }
        }

        page.batchList(ids, prices);

        vm.expectEmit(false, false, false, true, address(page));

        emit BatchCancel(ids);

        page.batchCancel(ids);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint96 listingPrice) = page.listings(id);

            assertEq(address(this), page.ownerOf(id));
            assertEq(1, page.balanceOf(address(this), id));
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
        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = 1 ether;

            unchecked {
                ++i;
            }
        }

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

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = price;

            unchecked {
                ++i;
            }
        }

        page.batchList(ids, prices);

        uint256 totalPriceETH;
        uint256 sellerBalanceBefore = address(this).balance;

        for (uint256 i = 0; i < ids.length; ) {
            totalPriceETH += prices[i];

            unchecked {
                ++i;
            }
        }

        address buyer = address(1);

        vm.deal(buyer, totalPriceETH);

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchBuy(ids);

        // Send enough ETH to cover seller proceeds but not tips
        page.batchBuy{value: totalPriceETH}(ids);

        assertEq(sellerBalanceBefore + totalPriceETH, address(this).balance);
        assertEq(buyerBalanceBefore - totalPriceETH, buyer.balance);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(buyer, page.ownerOf(ids[i]));
            assertEq(1, page.balanceOf(buyer, ids[i]));
            assertEq(0, page.balanceOf(address(page), ids[i]));
            assertEq(0, page.balanceOf(address(this), ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchBuyPartial(uint96 price) external {
        vm.assume(price != 0);

        // Listing id index - will be canceled before the buy, resulting
        // in only a partial buy
        uint256 cancelIndex = 1;

        uint96[] memory prices = new uint96[](ids.length);

        for (uint256 i = 0; i < ids.length; ) {
            prices[i] = price;

            unchecked {
                ++i;
            }
        }

        page.batchList(ids, prices);

        uint256 totalPriceETH;
        uint256 sellerBalanceBefore = address(this).balance;

        for (uint256 i = 0; i < ids.length; ) {
            if (i == cancelIndex) {
                ++i;
                continue;
            }

            totalPriceETH += prices[i];

            unchecked {
                ++i;
            }
        }

        page.cancel(ids[cancelIndex]);

        address buyer = address(1);

        vm.deal(buyer, totalPriceETH);

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchBuy(ids);

        // Send enough ETH to cover seller proceeds but not tips
        page.batchBuy{value: totalPriceETH}(ids);

        assertEq(sellerBalanceBefore + totalPriceETH, address(this).balance);
        assertEq(buyerBalanceBefore - totalPriceETH, buyer.balance);

        for (uint256 i = 0; i < ids.length; ) {
            if (i == cancelIndex) {
                assertEq(address(this), page.ownerOf(ids[i]));
                assertEq(1, page.balanceOf(address(this), ids[i]));

                ++i;
                continue;
            }

            assertEq(buyer, page.ownerOf(ids[i]));
            assertEq(1, page.balanceOf(buyer, ids[i]));
            assertEq(0, page.balanceOf(address(page), ids[i]));
            assertEq(0, page.balanceOf(address(this), ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
