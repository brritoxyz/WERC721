// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {Book} from "src/Book.sol";
import {Page} from "src/Page.sol";

contract DummyERC20 is ERC20("", "", 18) {
    constructor() payable {}
}

contract BookTest is Test {
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);
    bytes32 private constant DEPLOYMENT_SALT = keccak256("DEPLOYMENT_SALT");

    address[] private accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    Book private immutable book;
    Page private immutable page;
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
        book = new Book();
        bookAddr = address(book);
        (uint256 version, address implementation) = book.upgradePage(
            DEPLOYMENT_SALT,
            type(Page).creationCode
        );
        page = Page(book.createPage(LLAMA));
        pageImplementation = implementation;

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            implementation,
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

        vm.expectRevert("Initializable: contract is already initialized");

        page.initialize(LLAMA);
    }

    /*//////////////////////////////////////////////////////////////
                             upgradePage
    //////////////////////////////////////////////////////////////*/

    function testCannotUpgradePageBytecodeLengthZero() external {
        bytes memory bytecode = bytes("");

        vm.expectRevert(Book.Zero.selector);

        book.upgradePage(DEPLOYMENT_SALT, bytecode);
    }

    function testCannotUpgradePageUnauthorized() external {
        address caller = accounts[0];
        bytes memory bytecode = type(DummyERC20).creationCode;

        assertTrue(caller != book.owner());

        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");

        book.upgradePage(DEPLOYMENT_SALT, bytecode);
    }

    function testCannotUpgradePageDuplicateDeploymentZero() external {
        book.upgradePage(DEPLOYMENT_SALT, type(DummyERC20).creationCode);

        vm.expectRevert(Book.Zero.selector);

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
        address nextImplementation = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(book),
                            DEPLOYMENT_SALT,
                            keccak256(bytecode)
                        )
                    )
                )
            )
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

    function testCannotCreatePageCollectionInvalid() external {
        vm.expectRevert(Book.Zero.selector);

        book.createPage(ERC721(address(0)));
    }

    function testCreatePageRedeployWithoutStorage() external {
        assertEq(address(page), book.pages(pageImplementation, LLAMA));

        // Forward timestamp in order to produce a new CREATE2 salt
        vm.warp(block.timestamp + 1);

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            pageImplementation,
            keccak256(
                abi.encodePacked(LLAMA, book.SALT_FRAGMENT(), block.timestamp)
            ),
            address(book)
        );

        vm.expectEmit(true, true, false, true, address(book));

        emit CreatePage(pageImplementation, LLAMA, predeterminedPageAddress);

        address newPage = book.createPage(LLAMA);

        assertTrue(newPage != address(page));
        assertEq(predeterminedPageAddress, newPage);

        // Previously-stored Page contract should remain unchanged
        assertEq(address(page), book.pages(pageImplementation, LLAMA));

        // Should be initialized
        vm.expectRevert("Initializable: contract is already initialized");

        Page(newPage).initialize(LLAMA);
    }

    function testCreatePage(ERC721 collection) external {
        vm.assume(address(collection) != address(0));
        vm.assume(address(collection) != address(LLAMA));

        assertEq(address(0), book.pages(pageImplementation, collection));

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            pageImplementation,
            keccak256(
                abi.encodePacked(
                    collection,
                    book.SALT_FRAGMENT(),
                    block.timestamp
                )
            ),
            address(book)
        );

        vm.expectEmit(true, true, false, true, address(book));

        emit CreatePage(
            pageImplementation,
            collection,
            predeterminedPageAddress
        );

        address pageAddress = book.createPage(collection);

        assertEq(predeterminedPageAddress, pageAddress);
        assertEq(address(collection), address(Page(pageAddress).collection()));

        vm.expectRevert("Initializable: contract is already initialized");

        Page(pageAddress).initialize(collection);
    }
}
