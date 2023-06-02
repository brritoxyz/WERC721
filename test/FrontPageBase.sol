// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {FrontPage} from "src/FrontPage.sol";
import {FrontPageERC721} from "src/FrontPageERC721.sol";

contract FrontPageBase is Test, ERC721TokenReceiver {
    uint256 internal constant MAX_SUPPLY = 10_000;
    uint256 internal constant MINT_PRICE = 0.069 ether;

    FrontPage internal immutable page;
    FrontPageERC721 internal immutable collection;

    string internal name = "J.Page Ruma NFTs";
    string internal symbol = "RUMA";
    address payable internal creator = payable(address(this));
    address[] internal accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    receive() external payable {}

    constructor() {
        page = new FrontPage(
            name,
            symbol,
            payable(address(this)),
            MAX_SUPPLY,
            MINT_PRICE
        );
        collection = page.collection();

        // Assertions for FrontPage initialized state
        assertEq(page.maxSupply(), MAX_SUPPLY);
        assertEq(page.mintPrice(), MINT_PRICE);

        // Assertions for collection initialized state
        assertEq(collection.name(), name);
        assertEq(collection.symbol(), symbol);
        assertEq(collection.owner(), creator);
    }
}
