// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Page} from "src/Page.sol";
import {Book} from "src/Book.sol";

contract PageTests is Test {
    bytes32 internal constant STORAGE_SLOT_LOCKED = bytes32(uint256(0));
    bytes32 internal constant STORAGE_SLOT_INITIALIZED = bytes32(uint256(1));

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    /*//////////////////////////////////////////////////////////////
                             initialize
    //////////////////////////////////////////////////////////////*/

    function _testInitializeAlreadyInitialized(address pageAddress) internal {
        uint256 locked = uint256(vm.load(pageAddress, STORAGE_SLOT_LOCKED));
        bool initialized = vm.load(pageAddress, STORAGE_SLOT_INITIALIZED) ==
            bytes32(abi.encode(bool(true)));

        assertEq(1, locked);
        assertEq(true, initialized);

        vm.expectRevert(Page.AlreadyInitialized.selector);

        Page(pageAddress).initialize();
    }

    /*//////////////////////////////////////////////////////////////
                             collection
    //////////////////////////////////////////////////////////////*/

    function _testCollection(
        address collectionAddress,
        address pageAddress
    ) internal {
        ERC721 pageCollection = Page(pageAddress).collection();

        assertEq(collectionAddress, address(pageCollection));
        assertEq(
            keccak256(abi.encode(ERC721(collectionAddress))),
            keccak256(abi.encode(pageCollection))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             name
    //////////////////////////////////////////////////////////////*/

    function _testName(
        address collectionAddress,
        address pageAddress
    ) internal {
        string memory collectionName = ERC721(collectionAddress).name();
        string memory pageName = Page(pageAddress).name();

        assertEq(
            keccak256(abi.encode(collectionName)),
            keccak256(abi.encode(pageName))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             symbol
    //////////////////////////////////////////////////////////////*/

    function _testSymbol(
        address collectionAddress,
        address pageAddress
    ) internal {
        string memory collectionSymbol = ERC721(collectionAddress).symbol();
        string memory pageSymbol = Page(pageAddress).symbol();

        assertEq(
            keccak256(abi.encode(collectionSymbol)),
            keccak256(abi.encode(pageSymbol))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             tokenURI
    //////////////////////////////////////////////////////////////*/

    function _testTokenURI(
        address collectionAddress,
        address pageAddress,
        uint256 id
    ) internal {
        string memory collectionTokenURI = ERC721(collectionAddress).tokenURI(
            id
        );
        string memory pageTokenURI = Page(pageAddress).tokenURI(id);

        assertEq(
            keccak256(abi.encode(collectionTokenURI)),
            keccak256(abi.encode(pageTokenURI))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function _testDeposit(
        Page page,
        address msgSender,
        uint256 id,
        address recipient
    ) internal {
        ERC721 collection = page.collection();

        // Page must be approved to transfer tokens on behalf of the sender
        assertTrue(collection.isApprovedForAll(msgSender, address(page)));

        // Pre-deposit state
        assertEq(msgSender, collection.ownerOf(id));
        assertEq(address(0), page.ownerOf(id));
        assertEq(0, page.balanceOf(recipient, id));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(msgSender, address(page), id);

        page.deposit(id, recipient);

        // Post-deposit state
        assertEq(address(page), collection.ownerOf(id));
        assertEq(recipient, page.ownerOf(id));
        assertEq(1, page.balanceOf(recipient, id));
    }
}
