// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Moon} from "src/Moon.sol";
import {MoonBookFactory} from "src/MoonBookFactory.sol";
import {MoonBook} from "src/MoonBook.sol";

contract MoonBookTest is Test {
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

    function testCreateMoonBook(address msgSender, ERC721 collection) external {
        vm.assume(msgSender != address(0));
        vm.assume(address(collection) != address(0));
        vm.assume(address(collection) != address(LLAMA));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(factory));

        emit CreateMoonBook(msgSender, collection);

        MoonBook moonBook = factory.createMoonBook(collection);

        assertEq(address(moonBook), address(factory.moonBooks(collection)));
    }

    /*//////////////////////////////////////////////////////////////
                            list
    //////////////////////////////////////////////////////////////*/

    function testList(address msgSender, uint8 id, uint96 price) external {
        vm.assume(msgSender != address(0));

        _acquireNFT(id, msgSender);

        vm.startPrank(msgSender);

        LLAMA.setApprovalForAll(bookAddr, true);

        vm.expectEmit(true, true, true, true, address(LLAMA));

        emit Transfer(msgSender, bookAddr, id);

        book.list(id, price);

        vm.stopPrank();

        assertEq(bookAddr, LLAMA.ownerOf(id));

        (address listingSeller, uint96 listingPrice) = book.collectionListings(
            id
        );

        assertEq(msgSender, listingSeller);
        assertEq(price, listingPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            listMany
    //////////////////////////////////////////////////////////////*/

    function testListMany(address msgSender, uint8 iterations) external {
        vm.assume(msgSender != address(0));
        vm.assume(iterations != 0);
        vm.assume(iterations < 10);

        uint256[] memory ids = new uint256[](iterations);
        uint96[] memory prices = new uint96[](iterations);

        // Get NFTs for msg.sender
        for (uint256 i; i < iterations; ) {
            _acquireNFT(i, msgSender);

            ids[i] = i;
            prices[i] = uint96(i) * 1e18;

            unchecked {
                ++i;
            }
        }

        vm.startPrank(msgSender);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.listMany(ids, prices);

        vm.stopPrank();

        for (uint256 i; i < iterations; ) {
            uint256 id = ids[i];

            assertEq(bookAddr, LLAMA.ownerOf(id));

            (address listingSeller, uint96 listingPrice) = book
                .collectionListings(id);

            assertEq(msgSender, listingSeller);
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
        address msgSender = address(1);
        uint256 id = 0;
        uint96 price = 1e18;

        _acquireNFT(id, msgSender);

        vm.startPrank(msgSender);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        vm.stopPrank();
        vm.prank(address(0));
        vm.expectRevert(MoonBook.OnlySeller.selector);

        book.editListing(id, price);
    }

    function testEditListing(
        address msgSender,
        uint8 id,
        uint96 price,
        uint96 newPrice
    ) external {
        vm.assume(msgSender != address(0));
        vm.assume(price != newPrice);

        _acquireNFT(id, msgSender);

        vm.startPrank(msgSender);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        (address listingSeller, uint96 listingPrice) = book.collectionListings(
            id
        );

        assertEq(msgSender, listingSeller);
        assertEq(price, listingPrice);

        book.editListing(id, newPrice);

        vm.stopPrank();

        (listingSeller, listingPrice) = book.collectionListings(id);

        assertEq(msgSender, listingSeller);
        assertEq(newPrice, listingPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            cancelListing
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelListingOnlySeller() external {
        address msgSender = address(1);
        uint256 id = 0;
        uint96 price = 1e18;

        _acquireNFT(id, msgSender);

        vm.startPrank(msgSender);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        vm.stopPrank();
        vm.prank(address(0));
        vm.expectRevert(MoonBook.OnlySeller.selector);

        book.cancelListing(id);
    }

    function testCancelListing() external {
        address msgSender = address(1);
        uint256 id = 0;
        uint96 price = 1e18;

        _acquireNFT(id, msgSender);

        vm.startPrank(msgSender);

        LLAMA.setApprovalForAll(bookAddr, true);

        book.list(id, price);

        vm.stopPrank();

        (address listingSeller, uint96 listingPrice) = book.collectionListings(
            id
        );

        assertEq(bookAddr, LLAMA.ownerOf(id));
        assertEq(msgSender, listingSeller);
        assertEq(price, listingPrice);

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(LLAMA));

        emit Transfer(bookAddr, msgSender, id);

        book.cancelListing(id);

        (listingSeller, listingPrice) = book.collectionListings(id);

        assertEq(msgSender, LLAMA.ownerOf(id));
        assertEq(address(0), listingSeller);
        assertEq(0, listingPrice);
    }
}
