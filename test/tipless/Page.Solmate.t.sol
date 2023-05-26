// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {PageBase} from "test/tipless/PageBase.sol";

contract PageSolmateTest is Test, PageBase {
    function testCannotTransferFromNotAuthorized() public {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = ids[0];

        page.deposit(id, from);

        assertTrue(address(this) != page.ownerOf(id));

        vm.expectRevert("NOT_AUTHORIZED");

        page.transferFrom(from, to, id);
    }

    function testCannotBatchTransferFromNotAuthorized() public {
        address from = accounts[0];
        address to = accounts[1];

        uint256[] memory mintAmounts = new uint256[](ids.length);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;

        uint256[] memory transferAmounts = new uint256[](ids.length);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;

        page.batchDeposit(ids, from);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                assertTrue(address(this) != page.ownerOf(ids[i]));
            }
        }

        vm.expectRevert("NOT_AUTHORIZED");

        page.batchTransferFrom(from, to, ids);
    }

    function testTransferToEOA() public {
        address to = accounts[1];
        uint256 id = ids[0];

        page.deposit(id, address(this));
        page.transfer(to, id);

        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(address(this), id), 0);
    }

    function testTransferFromToEOA() public {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = ids[0];

        page.deposit(id, from);

        vm.prank(from);

        page.setApprovalForAll(address(this), true);
        page.transferFrom(from, to, id);

        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(from, id), 0);
    }

    function testTransferFromSelf() public {
        address to = accounts[0];
        uint256 id = ids[0];

        page.deposit(id, address(this));
        page.transferFrom(address(this), to, id);

        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(address(this), id), 0);
    }

    function testBatchTransferToEOA() public {
        address to = accounts[1];

        uint256[] memory mintAmounts = new uint256[](ids.length);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;

        uint256[] memory transferAmounts = new uint256[](ids.length);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;

        page.batchDeposit(ids, address(this));
        page.batchTransfer(to, ids);

        assertEq(page.balanceOf(address(this), ids[0]), 0);
        assertEq(page.balanceOf(to, ids[0]), 1);
        assertEq(page.balanceOf(address(this), ids[1]), 0);
        assertEq(page.balanceOf(to, ids[1]), 1);
        assertEq(page.balanceOf(address(this), ids[2]), 0);
        assertEq(page.balanceOf(to, ids[2]), 1);
    }

    function testBatchTransferFromToEOA() public {
        address from = accounts[0];
        address to = accounts[1];

        uint256[] memory mintAmounts = new uint256[](ids.length);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;

        uint256[] memory transferAmounts = new uint256[](ids.length);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;

        page.batchDeposit(ids, from);

        vm.prank(from);

        page.setApprovalForAll(address(this), true);
        page.batchTransferFrom(from, to, ids);

        assertEq(page.balanceOf(from, ids[0]), 0);
        assertEq(page.balanceOf(to, ids[0]), 1);
        assertEq(page.balanceOf(from, ids[1]), 0);
        assertEq(page.balanceOf(to, ids[1]), 1);
        assertEq(page.balanceOf(from, ids[2]), 0);
        assertEq(page.balanceOf(to, ids[2]), 1);
    }

    function testBatchTransferFromSelfToEOA() public {
        address to = accounts[1];

        uint256[] memory mintAmounts = new uint256[](ids.length);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;

        uint256[] memory transferAmounts = new uint256[](ids.length);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;

        page.batchDeposit(ids, address(this));
        page.batchTransferFrom(address(this), to, ids);

        assertEq(page.balanceOf(address(this), ids[0]), 0);
        assertEq(page.balanceOf(to, ids[0]), 1);
        assertEq(page.balanceOf(address(this), ids[1]), 0);
        assertEq(page.balanceOf(to, ids[1]), 1);
        assertEq(page.balanceOf(address(this), ids[2]), 0);
        assertEq(page.balanceOf(to, ids[2]), 1);
    }
}
