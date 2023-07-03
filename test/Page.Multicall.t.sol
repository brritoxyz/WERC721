// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Page} from "src/Page.sol";
import {PageBase} from "test//PageBase.sol";

contract PageExchangeTest is Test, PageBase {
    /*//////////////////////////////////////////////////////////////
                             multicall
    //////////////////////////////////////////////////////////////*/

    function testCannotMulticallInvalid() external {
        uint256 depositId = ids[0];
        address recipient = address(this);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(
            Page.deposit.selector,
            depositId,
            recipient
        );

        // Attempt to call `deposit` with the same ID, which will revert
        data[1] = abi.encodeWithSelector(
            Page.deposit.selector,
            depositId,
            recipient
        );

        // Custom error will include the reverted call index
        vm.expectRevert(
            abi.encodeWithSelector(Page.MulticallError.selector, 1)
        );

        page.multicall(data);
    }

    function testMulticall() external {
        uint256 id = ids[0];
        address recipient = address(this);
        uint96 price = 1 ether;

        assertEq(address(this), LLAMA.ownerOf(id));
        assertEq(address(0), page.ownerOf(id));
        assertEq(0, page.balanceOf(recipient, id));

        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeWithSelector(Page.deposit.selector, id, recipient);
        data[1] = abi.encodeWithSelector(
            Page.deposit.selector,
            ids[1],
            recipient
        );
        data[2] = abi.encodeWithSelector(Page.list.selector, id, price);
        data[3] = abi.encodeWithSelector(
            Page.withdraw.selector,
            ids[1],
            recipient
        );

        page.multicall(data);

        assertEq(address(page), LLAMA.ownerOf(id));
        assertEq(address(page), page.ownerOf(id));
        assertEq(1, page.balanceOf(address(page), id));

        (address seller, uint96 listingPrice) = page.listings(id);

        assertEq(address(this), seller);
        assertEq(price, listingPrice);
    }
}
