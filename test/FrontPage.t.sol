// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {FrontPageBook} from "src/frontPage/FrontPageBook.sol";
import {FrontPage} from "src/frontPage/FrontPage.sol";
import {FrontPageERC721} from "src/frontPage/FrontPageERC721.sol";
import {Page} from "src/Page.sol";
import {TestERC721} from "test/lib/TestERC721.sol";

contract FrontPageTests is Test, ERC721TokenReceiver {
    bytes32 internal constant SALT = keccak256("SALT");
    string internal constant NAME = "Test";
    string internal constant SYMBOL = "TEST";
    uint256 internal constant MAX_SUPPLY = 12_345;
    uint256 internal constant MINT_PRICE = 0.069 ether;

    FrontPageBook internal immutable book = new FrontPageBook();
    FrontPageERC721 internal immutable collection;
    FrontPage internal immutable page;

    receive() external payable {}

    constructor() {
        (uint256 collectionVersion, ) = book.upgradeCollection(
            SALT,
            type(FrontPageERC721).creationCode
        );

        // Call `upgradePage` and set the first page implementation
        (uint256 pageVersion, ) = book.upgradePage(
            SALT,
            type(FrontPage).creationCode
        );

        // Clone the collection and page implementations and assign to variables
        (address collectionAddress, address pageAddress) = book.createPage(
            FrontPageBook.CloneArgs({
                name: NAME,
                symbol: SYMBOL,
                creator: payable(address(this)),
                maxSupply: MAX_SUPPLY,
                mintPrice: MINT_PRICE
            }),
            collectionVersion,
            pageVersion,
            SALT,
            SALT
        );
        collection = FrontPageERC721(collectionAddress);
        page = FrontPage(pageAddress);
    }
}
