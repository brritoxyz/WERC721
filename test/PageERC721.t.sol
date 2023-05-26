// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {DSInvariantTest} from "solmate/test/utils/DSInvariantTest.sol";
import {MockERC721} from "solmate/test/utils/mocks/MockERC721.sol";
import {Book} from "src/Book.sol";
import {Page} from "src/Page.sol";

contract NonERC721Recipient {}

contract ERC721Test is DSTestPlus {
    address private constant ABCD = address(0xABCD);
    address private constant BEEF = address(0xBEEF);
    address private constant CAFE = address(0xCAFE);

    Book private book;
    Page private page;
    MockERC721 private token;

    function setUp() public {
        token = new MockERC721("Token", "TKN");
        book = new Book();

        book.upgradePage(keccak256("DEPLOYMENT_SALT"), type(Page).creationCode);

        page = Page(book.createPage(token));

        token.setApprovalForAll(address(page), true);
    }

    function _deposit(uint256 id, address recipient) internal {
        token.mint(address(this), id);
        page.deposit(id, recipient);
    }

    function testMint() public {
        uint256 id = 1337;

        _deposit(id, BEEF);

        assertEq(page.balanceOf(BEEF, id), 1);
        assertEq(page.ownerOf(id), BEEF);
    }

    function testApproveAll() public {
        page.setApprovalForAll(BEEF, true);

        assertTrue(page.isApprovedForAll(address(this), BEEF));
    }

    function testTransferFrom() public {
        address from = ABCD;
        address to = BEEF;
        uint256 id = 1337;

        _deposit(id, from);

        hevm.prank(from);

        page.setApprovalForAll(address(this), true);
        page.transferFrom(from, to, id);

        assertTrue(page.isApprovedForAll(from, address(this)));
        assertEq(page.ownerOf(id), to);
        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(from, id), 0);
    }

    function testTransferFromSelf() public {
        address to = BEEF;
        uint256 id = 1337;

        _deposit(id, address(this));

        page.transferFrom(address(this), to, id);

        assertEq(page.ownerOf(id), to);
        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(address(this), id), 0);
    }

    function testTransferFromApproveAll() public {
        address from = ABCD;
        address to = BEEF;
        uint256 id = 1337;

        _deposit(id, from);

        hevm.prank(from);

        page.setApprovalForAll(address(this), true);
        page.transferFrom(from, to, id);

        assertEq(page.ownerOf(id), to);
        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(from, id), 0);
    }

    function testFailTransferFromUnOwned() public {
        page.transferFrom(ABCD, BEEF, 1337);
    }

    function testFailTransferFromWrongFrom() public {
        uint256 id = 1337;

        _deposit(id, CAFE);

        page.transferFrom(ABCD, BEEF, id);
    }

    function testFailTransferFromToZero() public {
        uint256 id = 1337;

        _deposit(id, address(this));

        page.transferFrom(address(this), address(0), id);
    }

    function testFailTransferFromNotOwner() public {
        uint256 id = 1337;

        _deposit(id, address(this));

        page.transferFrom(ABCD, BEEF, id);
    }

    function testApproveAll(address to, bool approved) public {
        page.setApprovalForAll(to, approved);

        assertBoolEq(page.isApprovedForAll(address(this), to), approved);
    }

    function testTransferFrom(uint256 id, address to) public {
        address from = ABCD;

        if (to == address(0) || to == from) to = address(0xBEEF);

        _deposit(id, from);

        hevm.prank(from);

        page.setApprovalForAll(address(this), true);
        page.transferFrom(from, to, id);

        assertTrue(page.isApprovedForAll(from, address(this)));
        assertEq(page.ownerOf(id), to);
        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(from, id), 0);
    }

    function testTransferFromSelf(uint256 id, address to) public {
        if (to == address(0) || to == address(this)) to = BEEF;

        _deposit(id, address(this));

        page.transferFrom(address(this), to, id);

        assertEq(page.ownerOf(id), to);
        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(address(this), id), 0);
    }

    function testTransferFromApproveAll(uint256 id, address to) public {
        address from = ABCD;

        if (to == address(0) || to == from) to = BEEF;

        _deposit(id, from);

        hevm.prank(from);

        page.setApprovalForAll(address(this), true);
        page.transferFrom(from, to, id);

        assertTrue(page.isApprovedForAll(from, address(this)));
        assertEq(page.ownerOf(id), to);
        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(from, id), 0);
    }

    function testFailTransferFromUnOwned(
        address from,
        address to,
        uint256 id
    ) public {
        page.transferFrom(from, to, id);
    }

    function testFailTransferFromWrongFrom(
        address owner,
        address from,
        address to,
        uint256 id
    ) public {
        if (owner == address(0)) to = BEEF;
        if (from == owner) revert();

        _deposit(id, owner);

        page.transferFrom(from, to, id);
    }

    function testFailTransferFromToZero(uint256 id) public {
        _deposit(id, address(this));

        page.transferFrom(address(this), address(0), id);
    }

    function testFailTransferFromNotOwner(
        address from,
        address to,
        uint256 id
    ) public {
        if (from == address(this)) from = BEEF;

        _deposit(id, from);

        page.transferFrom(from, to, id);
    }
}
