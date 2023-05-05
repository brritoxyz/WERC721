// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {MoonBookV2} from "src/MoonBookV2.sol";
import {MoonPage} from "src/MoonPage.sol";

contract MoonBookV2Test is Test {
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    MoonBookV2 private immutable book;
    MoonPage private immutable page;

    constructor() {
        book = new MoonBookV2();

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            book.pageImplementation(),
            keccak256(abi.encodePacked(LLAMA, book.SALT_FRAGMENT())),
            address(book)
        );
        address pageAddress = book.createPage(LLAMA);

        assertEq(predeterminedPageAddress, pageAddress);

        page = MoonPage(pageAddress);

        assertTrue(book.pageImplementation() != address(0));
    }

    function testCannotCreatePageAlreadyCreated() external {
        assertEq(address(page), book.pages(LLAMA));

        vm.expectRevert(MoonBookV2.AlreadyCreated.selector);

        book.createPage(LLAMA);
    }

    function testCreatePage(ERC721 collection) external {
        vm.assume(address(collection) != address(LLAMA));

        assertEq(address(0), book.pages(collection));

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            book.pageImplementation(),
            keccak256(abi.encodePacked(collection, book.SALT_FRAGMENT())),
            address(book)
        );
        address pageAddress = book.createPage(collection);

        assertEq(predeterminedPageAddress, pageAddress);
        assertEq(address(this), MoonPage(pageAddress).owner());
        assertEq(address(collection), address(MoonPage(pageAddress).collection()));
    }
}
