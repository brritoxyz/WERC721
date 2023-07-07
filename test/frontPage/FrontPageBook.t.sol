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

    event UpgradeCollection(uint256 version, address implementation);
    event CreateFrontPage(
        address indexed page,
        uint256 indexed collectionVersion,
        uint256 indexed pageVersion
    );

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

    /*//////////////////////////////////////////////////////////////
                             createPage
    //////////////////////////////////////////////////////////////*/

    function testCannotCreatePageInvalidCollectionVersion() external {
        FrontPageBook.CloneArgs memory cloneArgs;
        uint256 invalidCollectionVersion = book.currentCollectionVersion() + 1;
        uint256 pageVersion = 0;
        bytes32 collectionSalt = bytes32(0);
        bytes32 pageSalt = bytes32(0);

        assertEq(
            address(0),
            book.collectionImplementations(invalidCollectionVersion)
        );

        vm.expectRevert(FrontPageBook.InvalidCollectionVersion.selector);

        book.createPage(
            cloneArgs,
            invalidCollectionVersion,
            pageVersion,
            collectionSalt,
            pageSalt
        );
    }

    function testCannotCreatePageInvalidPageVersion() external {
        FrontPageBook.CloneArgs memory cloneArgs;

        // This will be a valid version since we will deploy an implementation
        uint256 collectionVersion = book.currentCollectionVersion() + 1;

        uint256 invalidPageVersion = book.currentVersion() + 1;
        bytes32 collectionSalt = bytes32(0);
        bytes32 pageSalt = bytes32(0);

        book.upgradeCollection(
            collectionSalt,
            type(FrontPageERC721Initializable).creationCode
        );

        assertTrue(
            address(0) != book.collectionImplementations(collectionVersion)
        );
        assertEq(address(0), book.pageImplementations(invalidPageVersion));

        vm.expectRevert(FrontPageBook.InvalidPageVersion.selector);

        book.createPage(
            cloneArgs,
            collectionVersion,
            invalidPageVersion,
            collectionSalt,
            pageSalt
        );
    }

    function testCannotCreatePageDeploymentFailed() external {
        FrontPageBook.CloneArgs memory cloneArgs = FrontPageBook.CloneArgs({
            name: "Test",
            symbol: "TEST",
            creator: payable(address(this)),
            maxSupply: 1,
            mintPrice: 1
        });
        uint256 collectionVersion = book.currentCollectionVersion() + 1;
        uint256 pageVersion = book.currentVersion() + 1;
        bytes32 collectionSalt = bytes32(0);
        bytes32 pageSalt = bytes32(0);

        book.upgradeCollection(
            collectionSalt,
            type(FrontPageERC721Initializable).creationCode
        );
        book.upgradePage(pageSalt, type(FrontPageCWIA).creationCode);

        assertTrue(
            address(0) != book.collectionImplementations(collectionVersion)
        );
        assertTrue(address(0) != book.pageImplementations(pageVersion));

        book.createPage(
            cloneArgs,
            collectionVersion,
            pageVersion,
            collectionSalt,
            pageSalt
        );

        // Clone fails to deploy due to same salt and bytecode used twice for the collection
        vm.expectRevert(LibClone.DeploymentFailed.selector);

        book.createPage(
            cloneArgs,
            collectionVersion,
            pageVersion,
            collectionSalt,
            pageSalt
        );
    }

    function testCreatePage() external {
        FrontPageBook.CloneArgs memory cloneArgs = FrontPageBook.CloneArgs({
            name: "Test",
            symbol: "TEST",
            creator: payable(address(this)),
            maxSupply: 69,
            mintPrice: 420
        });
        uint256 collectionVersion = book.currentCollectionVersion() + 1;
        uint256 pageVersion = book.currentVersion() + 1;
        bytes32 collectionSalt = bytes32(0);
        bytes32 pageSalt = bytes32(0);

        book.upgradeCollection(
            collectionSalt,
            type(FrontPageERC721Initializable).creationCode
        );
        book.upgradePage(pageSalt, type(FrontPageCWIA).creationCode);

        address predictedCollection = LibClone.predictDeterministicAddress(
            book.collectionImplementations(collectionVersion),
            collectionSalt,
            address(book)
        );
        address predictedPage = LibClone.predictDeterministicAddress(
            book.pageImplementations(pageVersion),
            abi.encodePacked(
                predictedCollection,
                cloneArgs.creator,
                cloneArgs.maxSupply,
                cloneArgs.mintPrice
            ),
            pageSalt,
            address(book)
        );

        vm.expectEmit(true, true, true, true, address(book));

        emit CreateFrontPage(predictedPage, collectionVersion, pageVersion);

        (address collection, address page) = book.createPage(
            cloneArgs,
            collectionVersion,
            pageVersion,
            collectionSalt,
            pageSalt
        );

        assertEq(predictedCollection, collection);
        assertEq(predictedPage, page);

        FrontPageCWIA frontPage = FrontPageCWIA(page);

        assertEq(collection, address(frontPage.collection()));
        assertEq(cloneArgs.creator, frontPage.creator());
        assertEq(cloneArgs.maxSupply, frontPage.maxSupply());
        assertEq(cloneArgs.mintPrice, frontPage.mintPrice());

        FrontPageERC721Initializable frontPageERC721 = FrontPageERC721Initializable(
                collection
            );

        assertEq(cloneArgs.creator, frontPageERC721.owner());
        assertEq(
            keccak256(bytes(cloneArgs.name)),
            keccak256(bytes(frontPageERC721.name()))
        );
        assertEq(
            keccak256(bytes(cloneArgs.symbol)),
            keccak256(bytes(frontPageERC721.symbol()))
        );

        vm.expectRevert(FrontPageCWIA.AlreadyInitialized.selector);

        frontPage.initialize();

        vm.expectRevert(
            FrontPageERC721Initializable.AlreadyInitialized.selector
        );

        frontPageERC721.initialize(
            page,
            cloneArgs.creator,
            cloneArgs.name,
            cloneArgs.symbol
        );
    }
}
