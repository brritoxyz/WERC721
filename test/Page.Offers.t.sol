// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Page} from "src/Page.sol";
import {PageBase} from "test/PageBase.sol";

contract PageOffersTest is Test, PageBase {
    event MakeOffer(address maker);
    event CancelOffer(address maker);
    event TakeOffer(address taker);

    function _calculateOfferValue(
        uint256 price,
        uint256 quantity
    ) private view returns (uint256) {
        // Cannot overflow since price and quantity are upcasted from 48 and 168
        // (2**48 - 1) * (2**168 - 1) * 1e-8 is always less than (2**256 - 1)
        return price * quantity * valueDenom;
    }

    /*//////////////////////////////////////////////////////////////
                             makeOffer
    //////////////////////////////////////////////////////////////*/

    function testCannotMakeOfferPriceZero() external {
        vm.expectRevert(Page.Zero.selector);

        page.makeOffer(0, 1);
    }

    function testCannotMakeOfferQuantityPriceZero() external {
        vm.expectRevert(Page.Zero.selector);

        page.makeOffer(1, 0);
    }

    function testCannotMakeOfferMsgValueInsufficient() external {
        vm.expectRevert(Page.Insufficient.selector);

        page.makeOffer(1, 1);
    }

    function testMakeOffer(uint48 price, uint168 quantity) external {
        vm.assume(price != 0);
        vm.assume(quantity != 0);

        address msgSender;

        for (uint256 i; i < offerAccounts.length; ) {
            msgSender = offerAccounts[i];
            uint256 msgValue = _calculateOfferValue(price, quantity);
            uint256 previousOfferQuantity = page.offers(msgSender, price);

            vm.deal(msgSender, msgValue);

            uint256 msgSenderBalanceBefore = msgSender.balance;
            uint256 pageBalanceBefore = address(page).balance;

            vm.prank(msgSender);
            vm.expectEmit(false, false, false, true, address(page));

            emit MakeOffer(msgSender);

            page.makeOffer{value: msgValue}(price, quantity);

            assertEq(
                previousOfferQuantity + quantity,
                page.offers(msgSender, price)
            );
            assertEq(msgSenderBalanceBefore - msgValue, msgSender.balance);
            assertEq(pageBalanceBefore + msgValue, address(page).balance);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             cancelOffer
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelOfferPriceZero() external {
        vm.expectRevert(Page.Zero.selector);

        page.cancelOffer(0);
    }

    function testCannotCancelOfferQuantityZero() external {
        vm.expectRevert(Page.Zero.selector);

        page.cancelOffer(1);
    }

    function testCancelOffer(uint48 price, uint168 quantity) external {
        vm.assume(price != 0);
        vm.assume(quantity != 0);

        address msgSender;

        for (uint256 i; i < offerAccounts.length; ) {
            msgSender = offerAccounts[i];
            uint256 msgValue = _calculateOfferValue(price, quantity);
            uint256 previousOfferQuantity = page.offers(msgSender, price);

            vm.deal(msgSender, msgValue);
            vm.prank(msgSender);
            vm.expectEmit(false, false, false, true, address(page));

            emit MakeOffer(msgSender);

            page.makeOffer{value: msgValue}(price, quantity);

            assertEq(
                previousOfferQuantity + quantity,
                page.offers(msgSender, price)
            );

            unchecked {
                ++i;
            }
        }

        // Iterate over accounts (no duplicates accounts)
        for (uint256 i; i < accounts.length; ) {
            msgSender = accounts[i];
            uint256 msgSenderBalanceBefore = msgSender.balance;
            uint256 pageBalanceBefore = address(page).balance;
            uint256 totalOfferValue = _calculateOfferValue(
                price,
                page.offers(msgSender, price)
            );

            vm.prank(msgSender);
            vm.expectEmit(false, false, false, true, address(page));

            emit CancelOffer(msgSender);

            page.cancelOffer(price);

            assertEq(0, page.offers(msgSender, price));
            assertEq(
                msgSenderBalanceBefore + totalOfferValue,
                msgSender.balance
            );
            assertEq(
                pageBalanceBefore - totalOfferValue,
                address(page).balance
            );

            unchecked {
                ++i;
            }
        }
    }
}
