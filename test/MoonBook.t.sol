// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {MoonBook} from "src/MoonBook.sol";
import {Moon} from "src/Moon.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract MoonBookTest is Test {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint96;

    ERC20 private constant STAKER =
        ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ERC4626 private constant VAULT =
        ERC4626(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    MoonBook private immutable book;
    address private immutable bookAddr;
    uint128 private immutable moonFeePercent;
    uint128 private immutable moonFeePercentBase;

    address[3] private testSellers = [address(1), address(2), address(3)];
    address[3] private testBuyers = [address(4), address(5), address(6)];
    address[3] private testMakers = [address(7), address(8), address(9)];

    event CreateMoonBook(address indexed msgSender, ERC721 indexed collection);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event MakeOffer(
        address indexed msgSender,
        uint256 indexed offer,
        uint256 quantity
    );
    event CancelOffer(
        address indexed msgSender,
        uint256 indexed offer,
        uint256 quantity
    );
    event TakeOffer(
        address indexed msgSender,
        uint256 indexed offer,
        address indexed maker,
        uint256 quantity,
        uint256[] ids
    );

    constructor() {
        book = new MoonBook(address(STAKER), address(VAULT), LLAMA);
        bookAddr = address(book);
        moonFeePercent = book.MOON_FEE_PERCENT();
        moonFeePercentBase = book.MOON_FEE_PERCENT_BASE();

        assertEq(address(LLAMA), address(book.collection()));
    }

    function _acquireNFT(uint256 id, address recipient) private {
        address originalOwner = LLAMA.ownerOf(id);

        vm.prank(originalOwner);

        LLAMA.safeTransferFrom(originalOwner, recipient, id);
    }

    /*//////////////////////////////////////////////////////////////
                            list
    //////////////////////////////////////////////////////////////*/

    function testList(uint8 id, uint96 price) external {
        address seller = testSellers[0];

        vm.assume(seller != address(0));

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        vm.expectEmit(true, true, true, true, address(LLAMA));

        emit Transfer(seller, bookAddr, id);

        book.list(id, price);

        vm.stopPrank();

        assertEq(bookAddr, LLAMA.ownerOf(id));

        (address listingSeller, uint96 listingPrice) = book.collectionListings(
            id
        );

        assertEq(seller, listingSeller);
        assertEq(price, listingPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            listMany
    //////////////////////////////////////////////////////////////*/

    function testListMany(uint8 iterations) external {
        vm.assume(iterations != 0);
        vm.assume(iterations < 10);

        address seller = testSellers[0];
        uint256[] memory ids = new uint256[](iterations);
        uint96[] memory prices = new uint96[](iterations);

        // Get NFTs for msg.sender
        for (uint256 i; i < iterations; ) {
            _acquireNFT(i, seller);

            ids[i] = i;
            prices[i] = uint96(i) * 1 ether;

            unchecked {
                ++i;
            }
        }

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.listMany(ids, prices);

        vm.stopPrank();

        for (uint256 i; i < iterations; ) {
            uint256 id = ids[i];

            assertEq(bookAddr, LLAMA.ownerOf(id));

            (address listingSeller, uint96 listingPrice) = book
                .collectionListings(id);

            assertEq(seller, listingSeller);
            assertEq(prices[i], listingPrice);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            editListing
    //////////////////////////////////////////////////////////////*/

    function testCannotEditListingOnlySeller() external {
        address seller = testSellers[0];
        uint256 id = 0;
        uint96 price = 1 ether;

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        vm.stopPrank();
        vm.prank(address(0));
        vm.expectRevert(MoonBook.OnlySeller.selector);

        book.editListing(id, price);
    }

    function testEditListing(uint8 id, uint96 price, uint96 newPrice) external {
        vm.assume(price != newPrice);

        address seller = testSellers[0];

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        (address listingSeller, uint96 listingPrice) = book.collectionListings(
            id
        );

        assertEq(seller, listingSeller);
        assertEq(price, listingPrice);

        book.editListing(id, newPrice);

        vm.stopPrank();

        (listingSeller, listingPrice) = book.collectionListings(id);

        assertEq(seller, listingSeller);
        assertEq(newPrice, listingPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            cancelListing
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelListingOnlySeller() external {
        address seller = testSellers[0];
        uint256 id = 0;
        uint96 price = 1 ether;

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        vm.stopPrank();
        vm.prank(address(0));
        vm.expectRevert(MoonBook.OnlySeller.selector);

        book.cancelListing(id);
    }

    function testCancelListing() external {
        address seller = testSellers[0];
        uint256 id = 0;
        uint96 price = 1 ether;

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        vm.stopPrank();

        (address listingSeller, uint96 listingPrice) = book.collectionListings(
            id
        );

        assertEq(bookAddr, LLAMA.ownerOf(id));
        assertEq(seller, listingSeller);
        assertEq(price, listingPrice);

        vm.prank(seller);
        vm.expectEmit(true, true, true, true, address(LLAMA));

        emit Transfer(bookAddr, seller, id);

        book.cancelListing(id);

        (listingSeller, listingPrice) = book.collectionListings(id);

        assertEq(seller, LLAMA.ownerOf(id));
        assertEq(address(0), listingSeller);
        assertEq(0, listingPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            buy
    //////////////////////////////////////////////////////////////*/

    function testCannotBuyInvalidAmount() external {
        address seller = testSellers[0];
        uint256 id = 0;
        uint96 price = 1 ether;

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        vm.stopPrank();
        vm.expectRevert(Moon.InvalidAmount.selector);

        book.buy{value: price - 1}(id);
    }

    function testCannotBuyDoesNotExist(uint8 id) external {
        vm.expectRevert();

        book.buy{value: 0}(id);
    }

    function testBuy(uint8 id, uint96 price) external {
        vm.assume(price != 0);

        address seller = testSellers[0];
        address buyer = testBuyers[0];

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        vm.stopPrank();
        vm.deal(buyer, price);

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = buyer.balance;
        uint256 fees = price.mulDivDown(moonFeePercent, moonFeePercentBase);

        vm.prank(buyer);

        book.buy{value: price}(id);

        (address listingSeller, uint96 listingPrice) = book.collectionListings(
            id
        );

        assertEq(buyer, LLAMA.ownerOf(id));
        assertEq(address(0), listingSeller);
        assertEq(0, listingPrice);
        assertEq(buyerBalanceBefore - price, buyer.balance);
        assertEq(sellerBalanceBefore + price - fees, seller.balance);
        assertEq(fees, bookAddr.balance);
    }

    /*//////////////////////////////////////////////////////////////
                            makeOffer
    //////////////////////////////////////////////////////////////*/

    function testCannotMakeOfferOfferInvalidAmount(
        uint8 msgValue,
        uint256 quantity
    ) external {
        vm.assume(msgValue != 0);
        vm.assume(quantity != 0);

        uint256 value = uint256(msgValue) * 1 ether;
        uint256 offer = 0;

        vm.expectRevert(Moon.InvalidAmount.selector);

        book.makeOffer{value: value}(offer, quantity);
    }

    function testCannotMakeOfferQuantityInvalidAmount(
        uint8 msgValue,
        uint256 offer
    ) external {
        vm.assume(msgValue != 0);
        vm.assume(offer != 0);

        uint256 value = uint256(msgValue) * 1 ether;
        uint256 quantity = 0;

        vm.expectRevert(Moon.InvalidAmount.selector);

        book.makeOffer{value: value}(offer, quantity);
    }

    function testCannotMakeOfferValueInvalidAmount(
        uint8 offer,
        uint8 quantity
    ) external {
        vm.assume(offer != 0);
        vm.assume(quantity != 0);

        // If value is mismatched with offer * quantity, will revert
        uint256 value = uint256(offer) * uint256(quantity) + 1;

        vm.expectRevert(Moon.InvalidAmount.selector);

        book.makeOffer{value: value}(offer, quantity);
    }

    function testMakeOffer(uint8 offer, uint8 quantity) external {
        vm.assume(offer != 0);
        vm.assume(quantity != 0);

        address maker = testMakers[0];
        uint256 value = uint256(offer) * uint256(quantity);

        vm.deal(maker, value);
        vm.prank(maker);
        vm.expectEmit(true, false, false, true, bookAddr);

        emit MakeOffer(maker, offer, quantity);

        book.makeOffer{value: value}(offer, quantity);

        assertEq(quantity, book.collectionOffers(offer, maker));
    }

    /*//////////////////////////////////////////////////////////////
                            cancelOffer
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelOfferOfferInvalidAmount(
        uint256 quantity
    ) external {
        vm.assume(quantity != 0);

        uint256 offer = 0;

        vm.expectRevert(Moon.InvalidAmount.selector);

        book.cancelOffer(offer, quantity);
    }

    function testCannotCancelOfferQuantityInvalidAmount(
        uint256 offer
    ) external {
        vm.assume(offer != 0);

        uint256 quantity = 0;

        vm.expectRevert(Moon.InvalidAmount.selector);

        book.cancelOffer(offer, quantity);
    }

    function testCannotCancelOfferDoesNotExist(
        uint256 offer,
        uint256 quantity
    ) external {
        vm.assume(offer != 0);
        vm.assume(quantity != 0);
        vm.expectRevert(stdError.arithmeticError);

        book.cancelOffer(offer, quantity);
    }

    function testCancelOffer(
        uint128 offer,
        uint128 quantity,
        bool partialCancel
    ) external {
        vm.assume(offer != 0);
        vm.assume(quantity != 0);

        address maker = testMakers[0];
        uint256 value = uint256(offer) * uint256(quantity);

        vm.deal(maker, value);
        vm.prank(maker);

        book.makeOffer{value: value}(offer, quantity);

        assertEq(quantity, book.collectionOffers(offer, maker));

        // Quantity must be greater than 1, otherwise rounding down causes issues
        bool isPartialCancel = partialCancel && quantity > 1;

        uint256 cancelQuantity = quantity;

        if (isPartialCancel) {
            cancelQuantity = quantity / 2;
        }

        vm.prank(maker);
        vm.expectEmit(true, true, false, true, bookAddr);

        emit CancelOffer(maker, offer, cancelQuantity);

        book.cancelOffer(offer, cancelQuantity);

        assertEq(
            quantity - cancelQuantity,
            book.collectionOffers(offer, maker)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            takeOffer
    //////////////////////////////////////////////////////////////*/

    function testCannotTakeOfferOfferInvalidAmount(
        address maker,
        uint256 id
    ) external {
        vm.assume(maker != address(0));
        vm.assume(id != 0);

        uint256 offer = 0;

        vm.expectRevert(Moon.InvalidAmount.selector);

        book.takeOffer(offer, maker, id);
    }

    function testCannotTakeOfferMakerInvalidAddress(
        uint256 offer,
        uint256 id
    ) external {
        vm.assume(offer != 0);
        vm.assume(id != 0);

        address maker = address(0);

        vm.expectRevert(Moon.InvalidAddress.selector);

        book.takeOffer(offer, maker, id);
    }

    function testTakeOffer(uint128 offer, uint128 quantity, uint8 id) external {
        vm.assume(offer != 0);
        vm.assume(quantity != 0);
        vm.assume(id != 0);

        address maker = testMakers[0];
        address taker = testBuyers[0];
        uint256 value = uint256(offer) * uint256(quantity);

        vm.deal(maker, value);
        vm.prank(maker);

        book.makeOffer{value: value}(offer, quantity);

        _acquireNFT(id, taker);

        uint256 takerBalanceBefore = taker.balance;
        uint256 moonBalanceBefore = bookAddr.balance;
        uint256 expectedFees = uint256(offer).mulDivDown(
            moonFeePercent,
            moonFeePercentBase
        );

        vm.startPrank(taker);

        LLAMA.setApprovalForAll(bookAddr, true);

        vm.expectEmit(true, true, true, true, address(LLAMA));

        emit Transfer(taker, maker, id);

        book.takeOffer(offer, maker, id);

        vm.stopPrank();

        assertEq(takerBalanceBefore + offer - expectedFees, taker.balance);
        assertEq(moonBalanceBefore + expectedFees - offer, bookAddr.balance);
        assertEq(quantity - 1, book.collectionOffers(offer, maker));
        assertEq(maker, LLAMA.ownerOf(id));
        assertEq(expectedFees, book.balanceOf(taker));
    }
}
