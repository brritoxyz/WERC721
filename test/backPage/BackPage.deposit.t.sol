// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {BackPageBase} from "test/backPage/BackPageBase.sol";
import {PageDepositTests} from "test/base/Page.deposit.sol";

contract BackPageDepositTest is Test, BackPageBase, PageDepositTests {
    function testDeposit() external {
        TestDepositParams memory params = TestDepositParams({
            msgSender: address(this),
            id: ids[0],
            recipient: accounts[0]
        });

        _testDeposit(page, params);
    }
}
