// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BackPage} from "src/backPage/BackPage.sol";
import {BackPageBase} from "test/backPage/BackPageBase.sol";

contract BackPageTest is Test, BackPageBase {
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
            BackPage.onERC721Received.selector,
            page.onERC721Received(address(0), address(0), 1, "")
        );
    }
}
