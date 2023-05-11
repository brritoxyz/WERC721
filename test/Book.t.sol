// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Book} from "src/Book.sol";
import {Page} from "src/Page.sol";

contract DummyERC20 is ERC20("", "", 18) {}

contract DummyERC4626 is ERC4626(new DummyERC20(), "", "") {
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}

contract BookTest is Test {
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);
    address payable private constant TIP_RECIPIENT =
        payable(0x9c9dC2110240391d4BEe41203bDFbD19c279B429);

    address[] private accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    Book private immutable book;
    Page private immutable page;
    address private immutable bookAddr;

    event SetTipRecipient(address tipRecipient);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor() {
        book = new Book(TIP_RECIPIENT);
        bookAddr = address(book);

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            book.pageImplementation(),
            keccak256(abi.encodePacked(LLAMA, book.SALT_FRAGMENT())),
            address(book)
        );
        address pageAddress = book.createPage(LLAMA);

        page = Page(pageAddress);

        assertEq(address(this), book.owner());
        assertEq(address(this), page.owner());
        assertEq(predeterminedPageAddress, pageAddress);
        assertTrue(book.pageImplementation() != address(0));

        vm.expectRevert("Initializable: contract is already initialized");

        page.initialize(address(this), LLAMA, TIP_RECIPIENT);
    }

    /*//////////////////////////////////////////////////////////////
                             setTipRecipient
    //////////////////////////////////////////////////////////////*/

    function testCannotSetTipRecipientZero() external {
        vm.expectRevert(Book.Zero.selector);

        book.setTipRecipient(payable(address(0)));
    }

    function testCannotSetTipRecipientUnauthorized() external {
        address caller = accounts[0];

        assertTrue(caller != book.owner());

        vm.prank(caller);
        vm.expectRevert("UNAUTHORIZED");

        book.setTipRecipient(payable(address(0)));
    }

    function testSetTipRecipient() external {
        address caller = address(this);
        address payable tipRecipient = payable(accounts[0]);

        assertEq(caller, book.owner());
        assertTrue(tipRecipient != book.tipRecipient());

        vm.expectEmit(false, false, false, true, address(book));

        emit SetTipRecipient(tipRecipient);

        book.setTipRecipient(tipRecipient);

        assertEq(tipRecipient, book.tipRecipient());
    }

    /*//////////////////////////////////////////////////////////////
                             createPage
    //////////////////////////////////////////////////////////////*/

    function testCannotCreatePageCollectionInvalid() external {
        vm.expectRevert(Book.Zero.selector);

        book.createPage(ERC721(address(0)));
    }

    function testCannotCreatePageAlreadyCreated() external {
        assertEq(address(page), book.pages(LLAMA));

        vm.expectRevert(Book.AlreadyExists.selector);

        book.createPage(LLAMA);
    }

    function testCreatePage(ERC721 collection) external {
        vm.assume(address(collection) != address(0));
        vm.assume(address(collection) != address(LLAMA));

        assertEq(address(0), book.pages(collection));

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            book.pageImplementation(),
            keccak256(abi.encodePacked(collection, book.SALT_FRAGMENT())),
            address(book)
        );
        address pageAddress = book.createPage(collection);

        assertEq(predeterminedPageAddress, pageAddress);
        assertEq(address(this), Page(pageAddress).owner());
        assertEq(address(collection), address(Page(pageAddress).collection()));
        assertEq(TIP_RECIPIENT, Page(pageAddress).tipRecipient());

        vm.expectRevert("Initializable: contract is already initialized");

        Page(pageAddress).initialize(address(this), collection, TIP_RECIPIENT);
    }
}
