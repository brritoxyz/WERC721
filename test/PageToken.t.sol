// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {PageToken} from "src/PageToken.sol";

contract PageTokenImpl is PageToken {
    function name() external pure override returns (string memory) {
        return "Page";
    }

    function symbol() external pure override returns (string memory) {
        return "PAGE";
    }

    function tokenURI(uint256) external pure override returns (string memory) {
        return "";
    }

    function setOwnerOf(uint256 id, address owner) external {
        ownerOf[id] = owner;
    }
}

contract PageTokenTest is Test {
    PageTokenImpl private immutable pageToken = new PageTokenImpl();

    address[] internal accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    /*//////////////////////////////////////////////////////////////
                             setApprovalForAll
    //////////////////////////////////////////////////////////////*/

    function testSetApprovalForAllFalseToTrue() external {
        assertTrue(!pageToken.isApprovedForAll(address(this), accounts[0]));

        pageToken.setApprovalForAll(accounts[0], true);

        assertTrue(pageToken.isApprovedForAll(address(this), accounts[0]));
    }

    function testSetApprovalForAllTrueToFalse() external {
        pageToken.setApprovalForAll(accounts[0], true);

        assertTrue(pageToken.isApprovedForAll(address(this), accounts[0]));

        pageToken.setApprovalForAll(accounts[0], false);

        assertTrue(!pageToken.isApprovedForAll(address(this), accounts[0]));
    }

    function testSetApprovalForAllFuzz(
        address operator,
        bool approved
    ) external {
        pageToken.setApprovalForAll(operator, approved);

        assertEq(approved, pageToken.isApprovedForAll(address(this), operator));
    }

    /*//////////////////////////////////////////////////////////////
                             transfer
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferWrongFrom() external {
        address to = accounts[0];
        uint256 id = 1;

        assertEq(0, pageToken.balanceOf(address(this), id));

        vm.expectRevert(PageToken.WrongFrom.selector);

        pageToken.transfer(to, id);
    }

    function testCannotTransferUnsafeRecipient() external {
        address to = address(0);
        uint256 id = 1;

        pageToken.setOwnerOf(id, address(this));

        assertEq(1, pageToken.balanceOf(address(this), id));

        vm.expectRevert(PageToken.UnsafeRecipient.selector);

        pageToken.transfer(to, id);
    }

    function testTransfer() external {
        address to = accounts[0];
        uint256 id = 1;

        pageToken.setOwnerOf(id, address(this));

        assertEq(1, pageToken.balanceOf(address(this), id));
        assertEq(0, pageToken.balanceOf(to, id));

        pageToken.transfer(to, id);

        assertEq(0, pageToken.balanceOf(address(this), id));
        assertEq(1, pageToken.balanceOf(to, id));
    }

    function testTransferFuzz(uint256 id, address from, address to) external {
        vm.assume(from != address(0));
        vm.assume(from != to);

        pageToken.setOwnerOf(id, from);

        assertEq(1, pageToken.balanceOf(from, id));
        assertEq(0, pageToken.balanceOf(to, id));

        bool toIsUnsafe = to == address(0);

        vm.prank(from);

        if (toIsUnsafe) vm.expectRevert(PageToken.UnsafeRecipient.selector);

        pageToken.transfer(to, id);

        if (!toIsUnsafe) {
            assertEq(0, pageToken.balanceOf(from, id));
            assertEq(1, pageToken.balanceOf(to, id));
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchTransfer
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchTransferWrongFrom() external {
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[0];
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(0, pageToken.balanceOf(address(this), ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.expectRevert(PageToken.WrongFrom.selector);

        pageToken.batchTransfer(to, ids);
    }

    function testCannotBatchTransferUnsafeRecipient() external {
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = address(0);
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            pageToken.setOwnerOf(ids[i], address(this));

            assertEq(1, pageToken.balanceOf(address(this), ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.expectRevert(PageToken.UnsafeRecipient.selector);

        pageToken.batchTransfer(to, ids);
    }

    function testBatchTransfer() external {
        address[] memory to = new address[](accounts.length);
        uint256[] memory ids = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ) {
            to[i] = accounts[i];
            ids[i] = i;

            pageToken.setOwnerOf(ids[i], address(this));

            assertTrue(to[i] != address(0));
            assertEq(1, pageToken.balanceOf(address(this), ids[i]));
            assertEq(0, pageToken.balanceOf(to[i], ids[i]));

            unchecked {
                ++i;
            }
        }

        pageToken.batchTransfer(to, ids);

        for (uint256 i = 0; i < accounts.length; ) {
            assertEq(0, pageToken.balanceOf(address(this), ids[i]));
            assertEq(1, pageToken.balanceOf(to[i], ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             transferFrom
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferFromWrongFrom() external {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        assertEq(0, pageToken.balanceOf(from, id));

        vm.expectRevert(PageToken.WrongFrom.selector);

        pageToken.transferFrom(from, to, id);
    }

    function testCannotTransferFromUnsafeRecipient() external {
        address from = accounts[0];
        address to = address(0);
        uint256 id = 1;

        pageToken.setOwnerOf(id, from);

        assertEq(1, pageToken.balanceOf(from, id));

        vm.expectRevert(PageToken.UnsafeRecipient.selector);

        pageToken.transferFrom(from, to, id);
    }

    function testCannotTransferFromNotAuthorized() external {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        pageToken.setOwnerOf(id, from);

        assertEq(1, pageToken.balanceOf(from, id));
        assertTrue(!pageToken.isApprovedForAll(from, address(this)));

        vm.expectRevert(PageToken.NotAuthorized.selector);

        pageToken.transferFrom(from, to, id);
    }

    function testTransferFromSelf() external {
        address from = address(this);
        address to = accounts[1];
        uint256 id = 1;

        pageToken.setOwnerOf(id, from);

        assertEq(1, pageToken.balanceOf(from, id));
        assertEq(0, pageToken.balanceOf(to, id));

        pageToken.transferFrom(from, to, id);

        assertEq(0, pageToken.balanceOf(from, id));
        assertEq(1, pageToken.balanceOf(to, id));
    }

    function testTransferFrom() external {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = 1;

        pageToken.setOwnerOf(id, from);

        assertEq(1, pageToken.balanceOf(from, id));
        assertEq(0, pageToken.balanceOf(to, id));

        vm.prank(from);

        pageToken.setApprovalForAll(address(this), true);

        assertTrue(pageToken.isApprovedForAll(from, address(this)));
        assertTrue(address(this) != from);

        pageToken.transferFrom(from, to, id);

        assertEq(0, pageToken.balanceOf(from, id));
        assertEq(1, pageToken.balanceOf(to, id));
    }

    function testTransferFromFuzz(
        uint256 id,
        address from,
        address to,
        bool selfTransfer
    ) external {
        vm.assume(from != address(0));
        vm.assume(from != to);

        pageToken.setOwnerOf(id, from);

        assertEq(1, pageToken.balanceOf(from, id));
        assertEq(0, pageToken.balanceOf(to, id));

        vm.prank(from);

        if (!selfTransfer) {
            pageToken.setApprovalForAll(address(this), true);

            assertTrue(pageToken.isApprovedForAll(from, address(this)));
            assertTrue(address(this) != from);
        }

        bool toIsUnsafe = to == address(0);

        if (toIsUnsafe) vm.expectRevert(PageToken.UnsafeRecipient.selector);

        pageToken.transferFrom(from, to, id);

        if (!toIsUnsafe) {
            assertEq(0, pageToken.balanceOf(from, id));
            assertEq(1, pageToken.balanceOf(to, id));
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchTransferFrom
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchTransferFromNotAuthorized() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        assertTrue(!pageToken.isApprovedForAll(from, address(this)));
        assertTrue(from != address(this));

        vm.expectRevert(PageToken.NotAuthorized.selector);

        pageToken.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromWrongFromSelf() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(0, pageToken.balanceOf(from, ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);
        vm.expectRevert(PageToken.WrongFrom.selector);

        pageToken.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromWrongFrom() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = accounts[1];
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(0, pageToken.balanceOf(from, ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);

        pageToken.setApprovalForAll(address(this), true);

        assertTrue(pageToken.isApprovedForAll(from, address(this)));

        vm.expectRevert(PageToken.WrongFrom.selector);

        pageToken.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromUnsafeRecipientSelf() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = address(0);
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            pageToken.setOwnerOf(ids[i], from);

            assertEq(1, pageToken.balanceOf(from, ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);
        vm.expectRevert(PageToken.UnsafeRecipient.selector);

        pageToken.batchTransferFrom(from, to, ids);
    }

    function testCannotBatchTransferFromUnsafeRecipient() external {
        address from = accounts[0];
        address[] memory to = new address[](1);
        uint256[] memory ids = new uint256[](1);
        to[0] = address(0);
        ids[0] = 1;

        for (uint256 i = 0; i < ids.length; ) {
            pageToken.setOwnerOf(ids[i], from);

            assertEq(1, pageToken.balanceOf(from, ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);

        pageToken.setApprovalForAll(address(this), true);

        assertTrue(pageToken.isApprovedForAll(from, address(this)));

        vm.expectRevert(PageToken.UnsafeRecipient.selector);

        pageToken.batchTransferFrom(from, to, ids);
    }

    function testBatchTransferFromSelf() external {
        address from = address(1);
        address[] memory to = new address[](accounts.length);
        uint256[] memory ids = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ) {
            to[i] = accounts[i];
            ids[i] = i;

            pageToken.setOwnerOf(ids[i], from);

            assertEq(1, pageToken.balanceOf(from, ids[i]));
            assertEq(0, pageToken.balanceOf(to[i], ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(from);

        pageToken.batchTransferFrom(from, to, ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(0, pageToken.balanceOf(from, ids[i]));
            assertEq(1, pageToken.balanceOf(to[i], ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
