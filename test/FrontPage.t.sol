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

    address payable internal immutable creator = payable(address(this));
    FrontPageBook internal immutable book = new FrontPageBook();
    FrontPageERC721 internal immutable collection;
    FrontPage internal immutable page;

    address[] internal accounts = [address(1), address(2), address(3)];

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
                creator: creator,
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

    /*//////////////////////////////////////////////////////////////
                             collection
    //////////////////////////////////////////////////////////////*/

    function testCollection() external {
        assertEq(address(collection), address(page.collection()));
    }

    /*//////////////////////////////////////////////////////////////
                             creator
    //////////////////////////////////////////////////////////////*/

    function testCreator() external {
        assertEq(creator, page.creator());
    }

    /*//////////////////////////////////////////////////////////////
                             maxSupply
    //////////////////////////////////////////////////////////////*/

    function testMaxSupply() external {
        assertEq(MAX_SUPPLY, page.maxSupply());
    }

    /*//////////////////////////////////////////////////////////////
                             mintPrice
    //////////////////////////////////////////////////////////////*/

    function testMintPrice() external {
        assertEq(MINT_PRICE, page.mintPrice());
    }

    /*//////////////////////////////////////////////////////////////
                             withdrawProceeds
    //////////////////////////////////////////////////////////////*/

    function testCannotWithdrawProceedsUnauthorized() external {
        address unauthorizedMsgSender = accounts[0];

        assertTrue(unauthorizedMsgSender != page.creator());

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(Page.Unauthorized.selector);

        page.withdrawProceeds();
    }

    function testWithdrawProceeds() external {
        address msgSender = creator;
        uint256 offer = 1 ether;

        assertEq(msgSender, page.creator());

        vm.deal(msgSender, MINT_PRICE + offer);
        vm.prank(msgSender);

        // Mint to add ETH to the FrontPage that will be withdrawn
        page.mint{value: MINT_PRICE}();

        // Make an offer to add ETH to the FrontPage that should NOT be withdrawn
        page.makeOffer{value: offer}(offer, 1);

        // Verify that the FrontPage has
        assertEq(MINT_PRICE + offer, address(page).balance);

        uint256 mintProceeds = page.mintProceeds();
        uint256 pageBalanceBefore = address(page).balance;
        uint256 creatorBalanceBefore = address(msgSender).balance;

        vm.prank(msgSender);

        page.withdrawProceeds();

        assertEq(pageBalanceBefore - mintProceeds, address(page).balance);
        assertEq(offer, address(page).balance);
        assertEq(
            creatorBalanceBefore + mintProceeds,
            address(msgSender).balance
        );
    }
}
