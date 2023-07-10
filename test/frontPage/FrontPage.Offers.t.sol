// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FrontPage} from "src/frontPage/FrontPage.sol";
import {Page} from "src/Page.sol";
import {FrontPageBase} from "test/frontPage/FrontPageBase.sol";

contract FrontPageOffersTest is Test, FrontPageBase {
    event MakeOffer(address maker);
    event CancelOffer(address maker);
    event TakeOffer(address taker);

    /*//////////////////////////////////////////////////////////////
                             makeOffer
    //////////////////////////////////////////////////////////////*/

    function testCannotMakeOfferMsgValueInvalid(
        uint16 offerMultiplier,
        uint16 quantity,
        bool greaterOrLesser
    ) external {
        vm.assume(offerMultiplier != 0);
        vm.assume(quantity != 0);

        uint256 offerETH = uint256(offerMultiplier) * 1 ether;
        uint256 excessiveValue = offerETH * quantity + 1;
        uint256 insufficientValue = offerETH * quantity - 1;
        uint256 msgValue = greaterOrLesser ? excessiveValue : insufficientValue;

        vm.deal(address(this), msgValue);
        vm.expectRevert(Page.Invalid.selector);

        page.makeOffer{value: msgValue}(offerETH, quantity);
    }

    function testMakeOffer(uint16 offerMultiplier, uint16 quantity) external {
        uint256 offerETH = uint256(offerMultiplier) * 1 ether;
        uint256 msgValue = offerETH * quantity;
        uint256 makerBalanceBefore = address(this).balance;
        uint256 pageBalanceBefore = address(page).balance;

        assertEq(0, page.offers(address(this), offerETH));

        vm.expectEmit(false, false, false, true, address(page));

        emit MakeOffer(address(this));

        page.makeOffer{value: msgValue}(offerETH, quantity);

        assertEq(quantity, page.offers(address(this), offerETH));
        assertEq(makerBalanceBefore - msgValue, address(this).balance);
        assertEq(pageBalanceBefore + msgValue, address(page).balance);
    }

    /*//////////////////////////////////////////////////////////////
                             cancelOffer
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelOfferNonexistentArithmeticUnderflow(
        uint256 offer,
        uint256 quantity
    ) external {
        vm.assume(offer != 0);
        vm.assume(quantity != 0);
        vm.expectRevert(stdError.arithmeticError);

        // Reverts because the quantity is greater than the maker's offers
        // In this case, the maker will always have zero offer quantity
        page.cancelOffer(offer, quantity);
    }

    function testCancelOffer(
        uint16 offerMultiplier,
        uint16 quantity,
        uint16 cancelQuantity
    ) external {
        vm.assume(cancelQuantity <= quantity);

        address maker = address(this);
        uint256 offerETH = uint256(offerMultiplier) * 1 ether;
        uint256 msgValue = offerETH * quantity;

        // Make an offer to verify no state changes
        page.makeOffer{value: msgValue}(offerETH, quantity);

        uint256 makerBalanceBefore = maker.balance;
        uint256 pageBalanceBefore = address(page).balance;
        uint256 offerETHReceivedBack = cancelQuantity * offerETH;

        assertEq(quantity, page.offers(maker, offerETH));

        vm.expectEmit(false, false, false, true, address(page));

        emit CancelOffer(maker);

        page.cancelOffer(offerETH, cancelQuantity);

        assertEq(quantity - cancelQuantity, page.offers(maker, offerETH));
        assertEq(makerBalanceBefore + offerETHReceivedBack, maker.balance);
        assertEq(
            pageBalanceBefore - offerETHReceivedBack,
            address(page).balance
        );
    }

    /*//////////////////////////////////////////////////////////////
                             takeOffer
    //////////////////////////////////////////////////////////////*/

    function testCannotTakeOfferTakerQuantityExceedsMakerQuantity() external {
        address maker = accounts[0];
        uint256 offer = 1 ether;
        uint256 quantity = 1;
        uint256 msgValue = offer * quantity;

        vm.prank(maker);
        vm.deal(maker, msgValue);

        page.makeOffer{value: msgValue}(offer, quantity);

        assertLt(quantity, ids.length);

        vm.expectRevert(stdError.arithmeticError);

        page.takeOffer(ids, maker, offer);
    }

    function testCannotTakeOfferMakerZeroAddress() external {
        address maker = accounts[0];
        uint256 offer = 1 ether;
        uint256 quantity = 1;
        uint256 msgValue = offer * quantity;

        vm.prank(maker);
        vm.deal(maker, msgValue);

        page.makeOffer{value: msgValue}(offer, quantity);

        assertLt(quantity, ids.length);

        vm.expectRevert(stdError.arithmeticError);

        // Incorrect maker address specified
        page.takeOffer(ids, address(0), offer);
    }

    function testCannotTakeOfferPriceInvalid(bool greaterOrLesser) external {
        address maker = accounts[0];
        uint256 offer = 1 ether;
        uint256 quantity = 1;
        uint256 msgValue = offer * quantity;

        vm.prank(maker);
        vm.deal(maker, msgValue);

        page.makeOffer{value: msgValue}(offer, quantity);

        assertLt(quantity, ids.length);

        vm.expectRevert(stdError.arithmeticError);

        // Any offer that is not equal to the maker's offer will revert
        page.takeOffer(ids, maker, greaterOrLesser ? offer + 1 : offer - 1);
    }

    function testCannotTakeOfferUnauthorized() external {
        address maker = accounts[0];
        uint256 offer = 1 ether;
        uint256 quantity = 1;
        uint256 msgValue = offer * quantity;

        vm.prank(maker);
        vm.deal(maker, msgValue);

        page.makeOffer{value: msgValue}(offer, quantity);

        // Will revert since the owner of this ID is currently the zero address
        uint256[] memory _ids = new uint256[](1);
        _ids[0] = ids[0];

        // Zero address is guaranteed to not be the token owner
        vm.prank(address(0));
        vm.expectRevert(Page.Unauthorized.selector);

        // Any offer that is not equal to the maker's offer will revert
        page.takeOffer(_ids, maker, offer);
    }

    function testTakeOffer(uint16 offerMultiplier, uint8 quantity) external {
        vm.assume(offerMultiplier != 0);
        vm.assume(quantity != 0);
        vm.assume(quantity >= ids.length);

        address maker = accounts[0];
        uint256 offerETH = uint256(offerMultiplier) * 1 ether;
        uint256 msgValue = offerETH * quantity;

        vm.prank(maker);
        vm.deal(maker, msgValue);

        // Make an offer so we have something to take from
        page.makeOffer{value: msgValue}(offerETH, quantity);

        address taker = address(this);
        uint256 pageBalanceBefore = address(page).balance;
        uint256 takerBalanceBefore = taker.balance;
        uint256 makerOffersBefore = page.offers(maker, offerETH);
        uint256 takenValueETH = offerETH * ids.length;

        vm.expectEmit(false, false, false, true, address(page));

        emit TakeOffer(taker);

        page.takeOffer(ids, maker, offerETH);

        assertEq(pageBalanceBefore - takenValueETH, address(page).balance);
        assertEq(takerBalanceBefore + takenValueETH, taker.balance);
        assertEq(makerOffersBefore - ids.length, page.offers(maker, offerETH));

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(maker, page.ownerOf(ids[i]));
            assertEq(1, page.balanceOf(maker, ids[i]));
            assertEq(0, page.balanceOf(taker, ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
