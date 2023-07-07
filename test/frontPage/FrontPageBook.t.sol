// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {TestUtils} from "test/TestUtils.sol";
import {Book} from "src/Book.sol";
import {FrontPageBook} from "src/frontPage/FrontPageBook.sol";
import {FrontPageCWIA} from "src/frontPage/FrontPageCWIA.sol";
import {FrontPageERC721Initializable} from "src/frontPage/FrontPageERC721Initializable.sol";

contract FrontPageBookTest is Test {
    FrontPageBook private book;
    FrontPageCWIA private page;
    FrontPageERC721Initializable private collection;

    event UpgradeCollection(uint256 version, address implementation);

    constructor() {
        book = new FrontPageBook();
    }

    /*//////////////////////////////////////////////////////////////
                             upgradeCollection
    //////////////////////////////////////////////////////////////*/

    function testCannotUpgradeCollectionUnauthorized() external {
        address unauthorizedCaller = address(1);

        assertTrue(unauthorizedCaller != book.owner());

        vm.prank(unauthorizedCaller);
        vm.expectRevert(Ownable.Unauthorized.selector);

        book.upgradeCollection(
            bytes32(0),
            type(FrontPageERC721Initializable).creationCode
        );
    }

    function testCannotUpgradeCollectionEmptyBytes() external {
        assertEq(address(this), book.owner());

        vm.expectRevert(Book.EmptyBytecode.selector);

        book.upgradeCollection(bytes32(0), bytes(""));
    }

    function testCannotUpgradeCollectionCreate2Failed() external {
        assertEq(address(this), book.owner());

        book.upgradeCollection(
            bytes32(0),
            type(FrontPageERC721Initializable).creationCode
        );

        vm.expectRevert(Book.Create2Failed.selector);

        book.upgradeCollection(
            bytes32(0),
            type(FrontPageERC721Initializable).creationCode
        );
    }

    function testUpgradeCollection(bytes32 salt) external {
        uint256 nextCollectionVersion = book.currentCollectionVersion() + 1;

        assertEq(
            address(0),
            book.collectionImplementations(nextCollectionVersion)
        );
        assertEq(address(this), book.owner());

        bytes memory bytecode = type(FrontPageERC721Initializable).creationCode;
        address expectedImplementationAddress = TestUtils.computeCreate2Address(
            address(book),
            salt,
            bytecode
        );

        vm.expectEmit(false, false, false, true, address(book));

        emit UpgradeCollection(
            nextCollectionVersion,
            expectedImplementationAddress
        );

        (uint256 version, address implementation) = book.upgradeCollection(
            salt,
            bytecode
        );

        assertEq(nextCollectionVersion, version);
        assertEq(expectedImplementationAddress, implementation);
        assertEq(
            implementation,
            book.collectionImplementations(nextCollectionVersion)
        );
    }
}
