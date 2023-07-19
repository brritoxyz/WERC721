// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";
import {TestERC721} from "test/lib/TestERC721.sol";
import {ERC721TokenReceiver} from "src/lib/ERC721TokenReceiver.sol";
import {WERC721Factory} from "src/WERC721Factory.sol";
import {WERC721} from "src/WERC721.sol";
import {TestERC721SafeRecipient} from "test/lib/TestERC721SafeRecipient.sol";
import {TestERC721UnsafeRecipient} from "test/lib/TestERC721UnsafeRecipient.sol";

contract WERC721Test is Test, ERC721TokenReceiver {
    TestERC721 public immutable collection;
    WERC721Factory private immutable factory;
    WERC721 private immutable wrapperImplementation;
    WERC721 private immutable wrapper;

    // This emits when ownership of any NFT changes by any mechanism.
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    // This emits when an operator is enabled or disabled for an owner.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    constructor() {
        collection = new TestERC721();
        factory = new WERC721Factory();
        wrapperImplementation = factory.implementation();
        wrapper = WERC721(factory.create(collection));

        assertTrue(address(wrapperImplementation) != address(0));
        assertTrue(address(wrapper) != address(0));

        // Implementation should not have `collection` set.
        assertEq(address(0), address(wrapperImplementation.collection()));

        // Clone should have the `collection` set.
        assertEq(address(collection), address(wrapper.collection()));

        // Clone should have the same metadata as the ERC-721 collection.
        // `tokenURI` reverts if the token does not exist so cannot test yet.
        assertEq(collection.name(), wrapper.name());
        assertEq(collection.symbol(), wrapper.symbol());
    }

    /**
     * @notice Mint an ERC-721 and wrap it.
     * @param  owner  address  Wrapped ERC-721 NFT recipient.
     * @param  id     uint256  The NFT to mint and wrap.
     */
    function _mintWrap(address owner, uint256 id) internal {
        collection.mint(owner, id);

        vm.startPrank(owner);

        collection.approve(address(wrapper), id);
        wrapper.wrap(owner, id);

        vm.stopPrank();

        assertEq(address(wrapper), collection.ownerOf(id));
        assertEq(owner, wrapper.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             name
    //////////////////////////////////////////////////////////////*/

    function testName() external {
        assertEq(collection.name(), wrapper.name());
    }

    /*//////////////////////////////////////////////////////////////
                             symbol
    //////////////////////////////////////////////////////////////*/

    function testSymbol() external {
        assertEq(collection.symbol(), wrapper.symbol());
    }

    /*//////////////////////////////////////////////////////////////
                             tokenURI
    //////////////////////////////////////////////////////////////*/

    function testTokenURI() external {
        address msgSender = address(this);
        uint256 id = 0;

        _mintWrap(msgSender, id);

        assertEq(LibString.toString(id), wrapper.tokenURI(id));
    }

    /*//////////////////////////////////////////////////////////////
                             setApprovalForAll
    //////////////////////////////////////////////////////////////*/

    function testSetApprovalForAllFalseToTrue() external {
        address msgSender = address(this);
        address operator = address(1);
        bool approved = true;

        assertFalse(wrapper.isApprovedForAll(msgSender, operator));

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(wrapper));

        emit ApprovalForAll(msgSender, operator, approved);

        wrapper.setApprovalForAll(operator, approved);

        assertTrue(wrapper.isApprovedForAll(msgSender, operator));
    }

    function testSetApprovalForAllTrueToFalse() external {
        address msgSender = address(this);
        address operator = address(1);
        bool approvedTrue = true;

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(wrapper));

        emit ApprovalForAll(msgSender, operator, approvedTrue);

        wrapper.setApprovalForAll(operator, approvedTrue);

        assertTrue(wrapper.isApprovedForAll(msgSender, operator));

        bool approvedFalse = false;

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(wrapper));

        emit ApprovalForAll(msgSender, operator, approvedFalse);

        wrapper.setApprovalForAll(operator, approvedFalse);

        assertFalse(wrapper.isApprovedForAll(msgSender, operator));
    }

    function testSetApprovalForAllFuzz(
        address msgSender,
        address operator,
        bool approved
    ) external {
        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(wrapper));

        emit ApprovalForAll(msgSender, operator, approved);

        wrapper.setApprovalForAll(operator, approved);

        assertEq(approved, wrapper.isApprovedForAll(msgSender, operator));
    }

    /*//////////////////////////////////////////////////////////////
                             transferFrom
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferFromNotApprovedOperator() external {
        address msgSender = address(this);
        address from = address(1);
        address to = address(2);
        uint256 id = 0;

        assertFalse(wrapper.isApprovedForAll(from, msgSender));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.NotApprovedOperator.selector);

        wrapper.transferFrom(from, to, id);
    }

    function testCannotTransferFromNotTokenOwnerMsgSenderEqualsFrom() external {
        address msgSender = address(this);
        address from = msgSender;
        address to = address(2);
        uint256 id = 0;

        assertFalse(wrapper.isApprovedForAll(from, msgSender));
        assertEq(msgSender, from);
        assertTrue(from != wrapper.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.NotTokenOwner.selector);

        wrapper.transferFrom(from, to, id);
    }

    function testCannotTransferFromNotTokenOwnerMsgSenderApprovedOperator()
        external
    {
        address msgSender = address(this);
        address from = address(1);
        address to = address(2);
        uint256 id = 0;

        vm.prank(from);

        wrapper.setApprovalForAll(msgSender, true);

        assertTrue(wrapper.isApprovedForAll(from, msgSender));
        assertTrue(msgSender != from);
        assertTrue(from != wrapper.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.NotTokenOwner.selector);

        wrapper.transferFrom(from, to, id);
    }

    function testCannotTransferFromUnsafeTokenRecipient() external {
        address msgSender = address(this);
        address from = address(1);
        address to = address(0);
        uint256 id = 0;

        _mintWrap(from, id);

        vm.prank(from);

        wrapper.setApprovalForAll(msgSender, true);

        assertTrue(wrapper.isApprovedForAll(from, msgSender));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.UnsafeTokenRecipient.selector);

        wrapper.transferFrom(from, to, id);
    }

    function testTransferFromMsgSenderEqualsFrom() external {
        address msgSender = address(this);
        address from = msgSender;
        address to = address(2);
        uint256 id = 0;

        _mintWrap(from, id);

        assertEq(msgSender, from);
        assertEq(from, wrapper.ownerOf(id));
        assertFalse(wrapper.isApprovedForAll(from, msgSender));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(from, to, id);

        wrapper.transferFrom(from, to, id);
    }

    function testTransferFromMsgSenderApprovedOperator() external {
        address msgSender = address(this);
        address from = address(1);
        address to = address(2);
        uint256 id = 0;

        _mintWrap(from, id);

        assertTrue(msgSender != from);
        assertEq(from, wrapper.ownerOf(id));

        vm.prank(from);

        wrapper.setApprovalForAll(msgSender, true);

        assertTrue(wrapper.isApprovedForAll(from, msgSender));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(from, to, id);

        wrapper.transferFrom(from, to, id);
    }

    /*//////////////////////////////////////////////////////////////
                             safeTransferFrom
    //////////////////////////////////////////////////////////////*/

    function testCannotSafeTransferFromUnsafeTokenRecipient() external {
        address msgSender = address(this);
        address from = msgSender;
        address to = address(new TestERC721UnsafeRecipient());
        uint256 id = 0;
        bytes memory data = abi.encode(from);

        _mintWrap(from, id);

        assertEq(msgSender, from);
        assertEq(from, wrapper.ownerOf(id));
        assertTrue(to.code.length != 0);
        assertTrue(
            TestERC721UnsafeRecipient(to).onERC721Received(
                msgSender,
                from,
                id,
                data
            ) != ERC721TokenReceiver.onERC721Received.selector
        );

        vm.startPrank(msgSender);
        vm.expectRevert(WERC721.UnsafeTokenRecipient.selector);

        wrapper.safeTransferFrom(from, to, id, data);

        vm.expectRevert(WERC721.UnsafeTokenRecipient.selector);

        // `safeTransferFrom` without `data` param.
        wrapper.safeTransferFrom(from, to, id);

        vm.stopPrank();
    }

    function testSafeTransferFromWithData() external {
        address msgSender = address(this);
        address from = msgSender;
        address to = address(new TestERC721SafeRecipient());
        uint256 id = 0;
        bytes memory data = abi.encode(from);
        TestERC721SafeRecipient _to = TestERC721SafeRecipient(to);

        _mintWrap(from, id);

        assertEq(msgSender, from);
        assertEq(from, wrapper.ownerOf(id));
        assertTrue(to.code.length != 0);

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(from, to, id);

        wrapper.safeTransferFrom(from, to, id, data);

        assertEq(msgSender, _to.operator());
        assertEq(from, _to.from());
        assertEq(id, _to.id());
        assertEq(keccak256(data), keccak256(_to.data()));
        assertEq(
            _to.onERC721Received(msgSender, from, id, data),
            ERC721TokenReceiver.onERC721Received.selector
        );
    }

    function testSafeTransferFrom() external {
        address msgSender = address(this);
        address from = msgSender;
        address to = address(new TestERC721SafeRecipient());
        uint256 id = 0;
        TestERC721SafeRecipient _to = TestERC721SafeRecipient(to);

        _mintWrap(from, id);

        assertEq(msgSender, from);
        assertEq(from, wrapper.ownerOf(id));
        assertTrue(to.code.length != 0);

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(from, to, id);

        wrapper.safeTransferFrom(from, to, id);

        assertEq(msgSender, _to.operator());
        assertEq(from, _to.from());
        assertEq(id, _to.id());
        assertEq(
            _to.onERC721Received(msgSender, from, id, bytes("")),
            ERC721TokenReceiver.onERC721Received.selector
        );
    }

    /*//////////////////////////////////////////////////////////////
                             wrap
    //////////////////////////////////////////////////////////////*/

    function testCannotWrapUnsafeTokenRecipient() external {
        address msgSender = address(this);
        address to = address(0);
        uint256 id = 0;

        vm.prank(msgSender);
        vm.expectRevert(WERC721.UnsafeTokenRecipient.selector);

        wrapper.wrap(to, id);
    }

    function testCannotWrapERC721TokenDoesNotExist() external {
        address msgSender = address(this);
        address to = address(1);
        uint256 id = 0;

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);

        // Throws because the ERC-721 token has not been minted.
        collection.ownerOf(id);

        vm.prank(msgSender);
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);

        wrapper.wrap(to, id);
    }

    function testCannotWrapERC721TransferFromIncorrectOwner() external {
        address owner = address(2);
        address msgSender = address(this);
        address to = address(1);
        uint256 id = 0;

        collection.mint(owner, id);

        assertTrue(msgSender != collection.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(ERC721.TransferFromIncorrectOwner.selector);

        wrapper.wrap(to, id);
    }

    function testWrap() external {
        address msgSender = address(this);
        address to = address(1);
        uint256 id = 0;

        collection.mint(msgSender, id);

        assertEq(msgSender, collection.ownerOf(id));
        assertEq(address(0), wrapper.ownerOf(id));

        collection.setApprovalForAll(address(wrapper), true);

        assertTrue(collection.isApprovedForAll(msgSender, address(wrapper)));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(address(0), to, id);

        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(msgSender, address(wrapper), id);

        wrapper.wrap(to, id);

        assertEq(address(wrapper), collection.ownerOf(id));
        assertEq(to, wrapper.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             unwrap
    //////////////////////////////////////////////////////////////*/

    function testCannotUnwrapNotTokenOwner() external {
        address owner = address(2);
        address msgSender = address(this);
        address to = address(1);
        uint256 id = 0;

        _mintWrap(owner, id);

        assertTrue(msgSender != wrapper.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.NotTokenOwner.selector);

        wrapper.unwrap(to, id);
    }

    function testCannotUnwrapUnsafeTokenRecipient() external {
        address msgSender = address(this);
        address to = address(0);
        uint256 id = 0;

        _mintWrap(msgSender, id);

        vm.prank(msgSender);
        vm.expectRevert(WERC721.UnsafeTokenRecipient.selector);

        wrapper.unwrap(to, id);
    }

    function testUnwrap() external {
        address msgSender = address(this);
        address to = address(1);
        uint256 id = 0;

        _mintWrap(msgSender, id);

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(msgSender, address(0), id);

        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(address(wrapper), to, id);

        wrapper.unwrap(to, id);
    }

    /*//////////////////////////////////////////////////////////////
                             onERC721Received
    //////////////////////////////////////////////////////////////*/

    function testCannotOnERC721ReceivedNotAuthorizedCaller() external {
        address msgSender = address(this);
        uint256 id = 0;
        bytes memory data = abi.encode(address(1));

        assertTrue(msgSender != address(wrapper.collection()));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.NotAuthorizedCaller.selector);

        wrapper.onERC721Received(msgSender, msgSender, id, data);
    }

    function testCannotOnERC721ReceivedDataEmptyByteArray() external {
        address msgSender = address(collection);
        uint256 id = 0;
        bytes memory data = "";

        vm.prank(msgSender);
        vm.expectRevert();

        wrapper.onERC721Received(msgSender, msgSender, id, data);
    }

    function testCannotOnERC721ReceivedInvalidSafeWrap() external {
        address msgSender = address(collection);
        address to = address(1);
        uint256 id = 0;
        bytes memory data = abi.encode(to);

        // Mint token to avoid `TokenDoesNotExist` error but do not transfer to WERC721.
        collection.mint(msgSender, id);

        assertTrue(address(wrapper) != collection.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.InvalidSafeWrap.selector);

        wrapper.onERC721Received(msgSender, address(wrapper), id, data);
    }

    function testOnERC721ReceivedSafeTransferFrom() external {
        address msgSender = address(this);
        address to = address(1);
        uint256 id = 0;
        bytes memory data = abi.encode(to);

        collection.mint(msgSender, id);

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(collection));

        emit Transfer(msgSender, address(wrapper), id);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(address(0), to, id);

        collection.safeTransferFrom(msgSender, address(wrapper), id, data);

        assertEq(address(wrapper), collection.ownerOf(id));
        assertEq(to, wrapper.ownerOf(id));
    }

    function testOnERC721Received() external {
        address msgSender = address(collection);
        address to = address(1);
        uint256 id = 0;
        bytes memory data = abi.encode(to);

        // Mint the token for the WERC721 contract to ensure the `ownerOf` check does not throw.
        collection.mint(address(wrapper), id);

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(address(0), to, id);

        bytes4 selector = wrapper.onERC721Received(
            msgSender,
            address(wrapper),
            id,
            data
        );

        assertEq(to, wrapper.ownerOf(id));
        assertEq(selector, WERC721.onERC721Received.selector);
    }
}
