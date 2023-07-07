// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {TestUtils} from "test/TestUtils.sol";
import {BackPageBook} from "src/backPage/BackPageBook.sol";
import {Book} from "src/Book.sol";
import {BackPage} from "src/backPage/BackPage.sol";

contract DummyERC20 is ERC20("", "", 18) {
    constructor() payable {}
}

contract BackPageBookTest is Test {
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);
    bytes32 private constant DEPLOYMENT_SALT = keccak256("DEPLOYMENT_SALT");

    address[] private accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    BackPageBook private immutable book;
    BackPage private immutable page;
    address private immutable bookAddr;
    address private immutable pageImplementation;

    event UpgradePage(uint256 version, address implementation);
    event CreatePage(
        address indexed implementation,
        ERC721 indexed collection,
        address page
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor() {
        book = new BackPageBook();
        bookAddr = address(book);
        (uint256 version, address implementation) = book.upgradePage(
            DEPLOYMENT_SALT,
            type(BackPage).creationCode
        );
        page = BackPage(book.createPage(LLAMA, version));
        pageImplementation = implementation;

        address predeterminedPageAddress = LibClone.predictDeterministicAddress(
            implementation,
            abi.encodePacked(address(LLAMA)),
            keccak256(
                abi.encodePacked(LLAMA, book.SALT_FRAGMENT(), block.timestamp)
            ),
            address(book)
        );

        assertEq(address(this), book.owner());
        assertEq(version, book.currentVersion());
        assertEq(implementation, book.pageImplementations(1));
        assertEq(predeterminedPageAddress, address(page));
        assertTrue(version != 0);
        assertTrue(implementation != address(0));

        vm.expectRevert(BackPage.AlreadyInitialized.selector);

        page.initialize();
    }

    /*//////////////////////////////////////////////////////////////
                             upgradePage
    //////////////////////////////////////////////////////////////*/

    function testCannotUpgradePageEmptyBytecode() external {
        bytes memory bytecode = bytes("");

        vm.expectRevert(Book.EmptyBytecode.selector);

        book.upgradePage(DEPLOYMENT_SALT, bytecode);
    }

    function testCannotUpgradePageUnauthorized() external {
        address caller = accounts[0];
        bytes memory bytecode = type(DummyERC20).creationCode;

        assertTrue(caller != book.owner());

        vm.prank(caller);
        vm.expectRevert(Ownable.Unauthorized.selector);

        book.upgradePage(DEPLOYMENT_SALT, bytecode);
    }

    function testCannotUpgradePageCreate2Duplicate() external {
        book.upgradePage(DEPLOYMENT_SALT, type(DummyERC20).creationCode);

        vm.expectRevert(Book.Create2Failed.selector);

        book.upgradePage(DEPLOYMENT_SALT, type(DummyERC20).creationCode);
    }

    function testUpgradePage() external {
        assertEq(address(this), book.owner());

        bytes memory bytecode = type(DummyERC20).creationCode;
        uint256 currentVersion = book.currentVersion();
        address currentImplementation = book.pageImplementations(
            currentVersion
        );
        uint256 nextVersion = currentVersion + 1;
        address nextImplementation = TestUtils.computeCreate2Address(
            address(book),
            DEPLOYMENT_SALT,
            bytecode
        );

        vm.expectEmit(false, false, false, true, address(book));

        emit UpgradePage(nextVersion, nextImplementation);

        (uint256 version, address implementation) = book.upgradePage{
            value: 1 wei
        }(DEPLOYMENT_SALT, bytecode);

        assertEq(
            currentImplementation,
            book.pageImplementations(currentVersion)
        );
        assertTrue(currentVersion != book.currentVersion());
        assertTrue(
            currentImplementation != book.pageImplementations(nextVersion)
        );
        assertTrue(
            keccak256(currentImplementation.code) !=
                keccak256(implementation.code)
        );
        assertGt(currentImplementation.code.length, 0);
        assertGt(implementation.code.length, 0);
        assertEq(nextVersion, version);
        assertEq(nextImplementation, implementation);
        assertEq(version, book.currentVersion());
        assertEq(nextImplementation, book.pageImplementations(nextVersion));
    }

    /*//////////////////////////////////////////////////////////////
                             createPage
    //////////////////////////////////////////////////////////////*/

    function testCannotCreatePageZeroAddress() external {
        uint256 version = book.currentVersion();

        vm.expectRevert(BackPageBook.ZeroAddress.selector);

        book.createPage(ERC721(address(0)), version);
    }

    function testCannotCreatePageInvalidVersion() external {
        uint256 version = book.currentVersion() + 1;

        vm.expectRevert(BackPageBook.InvalidVersion.selector);

        book.createPage(LLAMA, version);
    }

    function testCreatePageRedeployWithoutStorage() external {
        assertEq(address(page), book.pages(pageImplementation, LLAMA));

        // Forward timestamp in order to produce a new CREATE2 salt
        vm.warp(block.timestamp + 1);

        address predeterminedPageAddress = LibClone.predictDeterministicAddress(
            pageImplementation,
            abi.encodePacked(address(LLAMA)),
            keccak256(
                abi.encodePacked(LLAMA, book.SALT_FRAGMENT(), block.timestamp)
            ),
            address(book)
        );
        uint256 version = book.currentVersion();

        vm.expectEmit(true, true, false, true, address(book));

        emit CreatePage(pageImplementation, LLAMA, predeterminedPageAddress);

        address newPage = book.createPage(LLAMA, version);

        assertTrue(newPage != address(page));
        assertEq(predeterminedPageAddress, newPage);

        // Previously-stored Page contract should remain unchanged
        assertEq(address(page), book.pages(pageImplementation, LLAMA));

        // Should be initialized
        vm.expectRevert(BackPage.AlreadyInitialized.selector);

        BackPage(newPage).initialize();
    }

    function testCreatePage(ERC721 collection) external {
        vm.assume(address(collection) != address(0));
        vm.assume(address(collection) != address(LLAMA));

        assertEq(address(0), book.pages(pageImplementation, collection));

        address predeterminedPageAddress = LibClone.predictDeterministicAddress(
            pageImplementation,
            abi.encodePacked(address(collection)),
            keccak256(
                abi.encodePacked(
                    collection,
                    book.SALT_FRAGMENT(),
                    block.timestamp
                )
            ),
            address(book)
        );
        uint256 version = book.currentVersion();

        vm.expectEmit(true, true, false, true, address(book));

        emit CreatePage(
            pageImplementation,
            collection,
            predeterminedPageAddress
        );

        address pageAddress = book.createPage(collection, version);

        assertEq(predeterminedPageAddress, pageAddress);
        assertEq(address(collection), BackPage(pageAddress).collection());

        vm.expectRevert(BackPage.AlreadyInitialized.selector);

        BackPage(pageAddress).initialize();
    }
}
