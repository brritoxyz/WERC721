// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Moon} from "src/Moon.sol";
import {MoonBookFactory} from "src/MoonBookFactory.sol";
import {MoonBook} from "src/MoonBook.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract MoonBookTest is Test {
    using FixedPointMathLib for uint96;

    ERC20 private constant STAKER =
        ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ERC4626 private constant VAULT =
        ERC4626(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    Moon private immutable moon;
    MoonBookFactory private immutable factory;
    MoonBook private immutable book;
    address private immutable bookAddr;
    uint128 private immutable moonFeePercent;
    uint128 private immutable moonFeePercentBase;

    address[3] private testSellers = [address(1), address(2), address(3)];
    address[3] private testBuyers = [address(4), address(5), address(6)];

    event CreateMoonBook(address indexed msgSender, ERC721 indexed collection);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    constructor() {
        moon = new Moon(STAKER, VAULT);
        factory = new MoonBookFactory(moon);
        book = factory.createMoonBook(LLAMA);
        bookAddr = address(book);
        moonFeePercent = book.MOON_FEE_PERCENT();
        moonFeePercentBase = book.MOON_FEE_PERCENT_BASE();

        assertEq(address(moon), address(factory.moon()));
        assertEq(address(moon), address(book.moon()));
        assertEq(address(LLAMA), address(book.collection()));
    }

    function _acquireNFT(uint256 id, address recipient) private {
        address originalOwner = LLAMA.ownerOf(id);

        vm.prank(originalOwner);

        LLAMA.safeTransferFrom(originalOwner, recipient, id);
    }

    /*//////////////////////////////////////////////////////////////
                            createMoonBook
    //////////////////////////////////////////////////////////////*/

    function testCannotCreateMoonBookAlreadyExists() external {
        vm.expectRevert(MoonBookFactory.AlreadyExists.selector);

        factory.createMoonBook(LLAMA);
    }

    function testCreateMoonBook(ERC721 collection) external {
        vm.assume(address(collection) != address(0));
        vm.assume(address(collection) != address(LLAMA));

        vm.expectEmit(true, true, true, true, address(factory));

        emit CreateMoonBook(address(this), collection);

        MoonBook moonBook = factory.createMoonBook(collection);

        assertEq(address(moonBook), address(factory.moonBooks(collection)));
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
        vm.expectRevert(MoonBook.InvalidAmount.selector);

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
        vm.expectEmit(true, true, true, true, address(LLAMA));

        emit Transfer(bookAddr, buyer, id);

        book.buy{value: price}(id);

        (address listingSeller, uint96 listingPrice) = book.collectionListings(
            id
        );

        assertEq(buyer, LLAMA.ownerOf(id));
        assertEq(address(0), listingSeller);
        assertEq(0, listingPrice);
        assertEq(buyerBalanceBefore - price, buyer.balance);
        assertEq(sellerBalanceBefore + price - fees, seller.balance);
        assertEq(fees, address(moon).balance);
    }
}
