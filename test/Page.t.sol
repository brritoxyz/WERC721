// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {PageBase} from "test/PageBase.sol";
import {Page} from "src/Page.sol";

contract PageTest is Test, PageBase {
    event Mint();
    event BatchMint();

    /*//////////////////////////////////////////////////////////////
                             name
    //////////////////////////////////////////////////////////////*/

    function testName() external {
        assertEq(LLAMA.name(), page.name());
    }

    /*//////////////////////////////////////////////////////////////
                             symbol
    //////////////////////////////////////////////////////////////*/

    function testSymbol() external {
        assertEq(LLAMA.symbol(), page.symbol());
    }

    /*//////////////////////////////////////////////////////////////
                             onERC721Received
    //////////////////////////////////////////////////////////////*/

    function testOnERC721Received() external {
        assertEq(
            Page.onERC721Received.selector,
            page.onERC721Received(address(0), address(0), 1, "")
        );
    }
}
