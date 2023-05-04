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
    uint128 private immutable withheldPercent;
    uint128 private immutable withheldPercentBase;

    address[3] private testSellers = [address(1), address(2), address(3)];
    address[3] private testBuyers = [address(4), address(5), address(6)];
    address[3] private testMakers = [address(7), address(8), address(9)];

    event CreateMoonBook(address indexed msgSender, ERC721 indexed collection);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    constructor() {
        book = new MoonBook(address(STAKER), address(VAULT));
        bookAddr = address(book);
        withheldPercent = book.WITHHELD_PERCENT();
        withheldPercentBase = book.WITHHELD_PERCENT_BASE();
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

        book.list(LLAMA, id, price);

        vm.stopPrank();

        assertEq(bookAddr, LLAMA.ownerOf(id));

        (address listingSeller, uint96 listingPrice) = book.listings(LLAMA, id);

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
        ERC721[] memory collections = new ERC721[](iterations);
        uint256[] memory ids = new uint256[](iterations);
        uint96[] memory prices = new uint96[](iterations);

        // Get NFTs for msg.sender
        for (uint256 i; i < iterations; ) {
            _acquireNFT(i, seller);

            collections[i] = LLAMA;
            ids[i] = i;
            prices[i] = uint96(i) * 1 ether;

            unchecked {
                ++i;
            }
        }

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.listMany(collections, ids, prices);

        vm.stopPrank();

        for (uint256 i; i < iterations; ) {
            uint256 id = ids[i];

            assertEq(bookAddr, LLAMA.ownerOf(id));

            (address listingSeller, uint96 listingPrice) = book.listings(
                LLAMA,
                id
            );

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

        book.list(LLAMA, id, price);

        vm.stopPrank();
        vm.prank(address(0));
        vm.expectRevert(MoonBook.OnlySeller.selector);

        book.editListing(LLAMA, id, price);
    }

    function testEditListing(uint8 id, uint96 price, uint96 newPrice) external {
        vm.assume(price != newPrice);

        address seller = testSellers[0];

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(LLAMA, id, price);

        (address listingSeller, uint96 listingPrice) = book.listings(LLAMA, id);

        assertEq(seller, listingSeller);
        assertEq(price, listingPrice);

        book.editListing(LLAMA, id, newPrice);

        vm.stopPrank();

        (listingSeller, listingPrice) = book.listings(LLAMA, id);

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

        book.list(LLAMA, id, price);

        vm.stopPrank();
        vm.prank(address(0));
        vm.expectRevert(MoonBook.OnlySeller.selector);

        book.cancelListing(LLAMA, id);
    }

    function testCancelListing() external {
        address seller = testSellers[0];
        uint256 id = 0;
        uint96 price = 1 ether;

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(LLAMA, id, price);

        vm.stopPrank();

        (address listingSeller, uint96 listingPrice) = book.listings(LLAMA, id);

        assertEq(bookAddr, LLAMA.ownerOf(id));
        assertEq(seller, listingSeller);
        assertEq(price, listingPrice);

        vm.prank(seller);
        vm.expectEmit(true, true, true, true, address(LLAMA));

        emit Transfer(bookAddr, seller, id);

        book.cancelListing(LLAMA, id);

        (listingSeller, listingPrice) = book.listings(LLAMA, id);

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

        book.list(LLAMA, id, price);

        vm.stopPrank();
        vm.expectRevert(Moon.InvalidAmount.selector);

        book.buy{value: price - 1}(LLAMA, id);
    }

    function testCannotBuyDoesNotExist(uint8 id) external {
        vm.expectRevert();

        book.buy{value: 0}(LLAMA, id);
    }

    function testBuy(uint8 id, uint96 price) external {
        vm.assume(price != 0);

        address seller = testSellers[0];
        address buyer = testBuyers[0];

        _acquireNFT(id, seller);

        vm.startPrank(seller);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(LLAMA, id, price);

        vm.stopPrank();
        vm.deal(buyer, price);

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = buyer.balance;
        uint256 fees = price.mulDivDown(withheldPercent, withheldPercentBase);

        vm.prank(buyer);

        book.buy{value: price}(LLAMA, id);

        (address listingSeller, uint96 listingPrice) = book.listings(LLAMA, id);

        assertEq(buyer, LLAMA.ownerOf(id));
        assertEq(address(0), listingSeller);
        assertEq(0, listingPrice);
        assertEq(buyerBalanceBefore - price, buyer.balance);
        assertEq(sellerBalanceBefore + price - fees, seller.balance);
        assertEq(fees, bookAddr.balance);
    }
}
