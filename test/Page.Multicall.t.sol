// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Page} from "src/Page.sol";
import {PageBase} from "test//PageBase.sol";

contract PageExchangeTest is Test, PageBase {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );
    event SetTipRecipient(address tipRecipient);
    event List(uint256 id);
    event Edit(uint256 id);
    event Cancel(uint256 id);
    event Buy(uint256 id);
    event BatchList(uint256[] ids);
    event BatchEdit(uint256[] ids);
    event BatchCancel(uint256[] ids);
    event BatchBuy(uint256[] ids);

    /*//////////////////////////////////////////////////////////////
                             multicall
    //////////////////////////////////////////////////////////////*/

    function testDepositList() external {
        uint256 id = ids[0];
        address recipient = address(this);
        uint96 price = 1 ether;

        assertEq(address(this), LLAMA.ownerOf(id));
        assertEq(address(0), page.ownerOf(id));
        assertEq(0, page.balanceOf(recipient, id));

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(Page.deposit.selector, id, recipient);
        data[1] = abi.encodeWithSelector(Page.list.selector, id, price);

        page.multicall(data, false);

        assertEq(address(page), LLAMA.ownerOf(id));
        assertEq(address(page), page.ownerOf(id));
        assertEq(1, page.balanceOf(address(page), id));

        (address seller, uint96 listingPrice) = page.listings(id);

        assertEq(address(this), seller);
        assertEq(price, listingPrice);
    }
}
