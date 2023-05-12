// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC1155TokenReceiver} from "src/base/ERC1155NS.sol";
import {PageBase} from "test/PageBase.sol";

contract ERC1155Recipient is ERC1155TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    uint256 public amount;
    bytes public mintData;

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) public override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        amount = _amount;
        mintData = _data;

        return ERC1155TokenReceiver.onERC1155Received.selector;
    }
}

contract PageTest is Test, PageBase {
    /*//////////////////////////////////////////////////////////////
                             safeTransferFrom
    //////////////////////////////////////////////////////////////*/

    function testSafeTransferFromToEOA(
        uint256 amount,
        bytes calldata data
    ) public {
        address from = accounts[0];
        address to = accounts[1];
        uint256 id = ids[0];

        page.deposit(id, from);

        vm.prank(from);

        page.setApprovalForAll(address(this), true);
        page.safeTransferFrom(from, to, id, amount, data);

        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(from, id), 0);
    }

    function testSafeTransferFromToERC1155Recipient(
        uint256 amount,
        bytes calldata data
    ) public {
        ERC1155Recipient to = new ERC1155Recipient();

        address from = accounts[0];
        uint256 id = ids[0];

        page.deposit(id, from);

        vm.prank(from);

        page.setApprovalForAll(address(this), true);
        page.safeTransferFrom(from, address(to), id, amount, data);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), from);
        assertEq(to.id(), id);
        assertEq(to.mintData(), bytes(""));

        assertEq(page.balanceOf(address(to), id), 1);
        assertEq(page.balanceOf(from, id), 0);
    }

    function testSafeTransferFromSelf(
        uint256 amount,
        bytes calldata data
    ) public {
        address to = accounts[0];
        uint256 id = ids[0];

        page.deposit(id, address(this));
        page.safeTransferFrom(address(this), to, id, amount, data);

        assertEq(page.balanceOf(to, id), 1);
        assertEq(page.balanceOf(address(this), id), 0);
    }

    function testSafeBatchTransferFromToEOA() public {
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
        page.safeBatchTransferFrom(from, to, ids, transferAmounts, "");

        assertEq(page.balanceOf(from, ids[0]), 0);
        assertEq(page.balanceOf(to, ids[0]), 1);
        assertEq(page.balanceOf(from, ids[1]), 0);
        assertEq(page.balanceOf(to, ids[1]), 1);
        assertEq(page.balanceOf(from, ids[2]), 0);
        assertEq(page.balanceOf(to, ids[2]), 1);
    }

    function testSafeBatchTransferFromToERC1155Recipient() public {
        address from = accounts[0];

        ERC1155Recipient to = new ERC1155Recipient();

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
        page.safeBatchTransferFrom(
            from,
            address(to),
            ids,
            transferAmounts,
            "testing 123"
        );

        assertEq(page.balanceOf(from, ids[0]), 0);
        assertEq(page.balanceOf(address(to), ids[0]), 1);
        assertEq(page.balanceOf(from, ids[1]), 0);
        assertEq(page.balanceOf(address(to), ids[1]), 1);
        assertEq(page.balanceOf(from, ids[2]), 0);
        assertEq(page.balanceOf(address(to), ids[2]), 1);
    }
}
