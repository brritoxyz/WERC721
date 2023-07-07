// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {FrontPageBook} from "src/frontPage/FrontPageBook.sol";
import {FrontPage} from "src/frontPage/FrontPage.sol";
import {FrontPageERC721} from "src/frontPage/FrontPageERC721.sol";

contract FrontPageBase is Test, ERC721TokenReceiver {
    uint256 internal constant MAX_SUPPLY = 10_000;
    uint256 internal constant MINT_PRICE = 0.069 ether;

    FrontPageBook internal immutable book;
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

    // Minted token IDs for testing
    uint256[] internal ids = [1, 2, 3];

    receive() external payable {}

    constructor() {
        book = new FrontPageBook();

        book.upgradeCollection(bytes32(0), type(FrontPageERC721).creationCode);
        book.upgradePage(bytes32(0), type(FrontPage).creationCode);
        (address newCollection, address newPage) = book.createPage(
            FrontPageBook.CloneArgs(
                name,
                symbol,
                creator,
                MAX_SUPPLY,
                MINT_PRICE
            ),
            book.currentCollectionVersion(),
            book.currentVersion(),
            bytes32(0),
            bytes32(0)
        );

        page = FrontPage(newPage);
        collection = FrontPageERC721(newCollection);

        // Assertions for FrontPage initialized state
        assertEq(page.maxSupply(), MAX_SUPPLY);
        assertEq(page.mintPrice(), MINT_PRICE);

        // Assertions for collection initialized state
        assertEq(collection.name(), name);
        assertEq(collection.symbol(), symbol);
        assertEq(collection.owner(), creator);

        // Mint token IDs
        uint256 quantity = ids.length;
        uint256 msgValue = quantity * MINT_PRICE;

        vm.deal(address(this), msgValue);

        page.batchMint{value: msgValue}(quantity);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(this), page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
