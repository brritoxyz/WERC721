// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Page} from "src/Page.sol";
import {PageBase} from "test/PageBase.sol";

contract PageOffersTest is Test, PageBase {
    event MakeOffer(address maker);
    event CancelOffer(address maker);
    event TakeOffer(address taker);
}
