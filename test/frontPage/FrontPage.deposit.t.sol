// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {FrontPageBase} from "test/frontPage/FrontPageBase.sol";
import {PageDepositTests} from "test/base/Page.deposit.sol";

contract FrontPageBookTest is Test, FrontPageBase, PageDepositTests {
    function testDeposit() external {
        TestDepositParams memory params = TestDepositParams({
            msgSender: address(this),
            id: ids[0],
            recipient: accounts[0]
        });
        ERC721 collection = page.collection();

        // Approve the FrontPage contract to transfer the ERC-721 on our behalf when depositing
        collection.setApprovalForAll(address(page), true);

        // Prior to redemption, the Page token should be owner by us
        assertEq(address(this), page.ownerOf(params.id));

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);

        // Should revert since the token has not yet been minted (i.e. redeemed)
        collection.ownerOf(params.id);

        // Redeem the Page token for the ERC-721 token to test depositing
        page.redeem(params.id);

        _testDeposit(page, params);
    }
}
