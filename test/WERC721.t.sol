// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";
import {WERC721Factory} from "src/WERC721Factory.sol";
import {WERC721} from "src/WERC721.sol";
import {TestERC721} from "test/lib/TestERC721.sol";
import {ERC721TokenReceiver} from "test/lib/ERC721TokenReceiver.sol";
import {TestERC721SafeRecipient} from "test/lib/TestERC721SafeRecipient.sol";
import {TestERC721UnsafeRecipient} from "test/lib/TestERC721UnsafeRecipient.sol";

contract WERC721Test is Test, ERC721TokenReceiver {
    // Position of the mapping within the WERC721 contract.
    // Retrieve from contract output file after running `forge build --extra-output storageLayout`.
    uint256 private constant STORAGE_SLOT_AUTHORIZATION_STATE = 2;

    // Anvil test account and private key for testing `transferFromWithAuthorization.
    address private constant TEST_ACCT =
        0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
    uint256 private constant TEST_ACCT_PRIV_KEY =
        0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6;

    // keccak256("TransferFromWithAuthorization(address relayer,address from,address to,uint256 tokenId,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 private constant TRANSFER_FROM_WITH_AUTHORIZATION_TYPEHASH =
        0x0e3210998bc7d4519a993d9c986d16a1be38c22a169884883d35e6a2e9bff24d;

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

    // This emits when an authorization is used.
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    // This emits when an authorization is canceled.
    event AuthorizationCanceled(
        address indexed authorizer,
        bytes32 indexed nonce
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

        // Clone should have the same metadata as the ERC721 collection.
        // `tokenURI` reverts if the token does not exist so cannot test yet.
        assertEq(collection.name(), wrapper.name());
        assertEq(collection.symbol(), wrapper.symbol());
    }

    /**
     * @notice Mint an ERC721 and wrap it.
     * @param  owner  address  Wrapped ERC721 NFT recipient.
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

    /**
     * @notice Sign a `transferFromWithAuthorization` authorization.
     * @param  privateKey   uint256  Authorizer/from private key.
     * @param  relayer      address  The authorized transfer tx relayer.
     * @param  from         address  The current owner of the NFT and authorizer.
     * @param  to           address  The new owner.
     * @param  id           uint256  The NFT to transfer.
     * @param  validAfter   uint256  The time after which this is valid (unix time).
     * @param  validBefore  uint256  The time before which this is valid (unix time).
     * @param  nonce        bytes32  Unique nonce.
     * @return              uint8    Signature param.
     * @return              bytes32  Signature param.
     * @return              bytes32  Signature param.
     */
    function _signTransferFromWithAuthorizationDigest(
        uint256 privateKey,
        address relayer,
        address from,
        address to,
        uint256 id,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce
    ) internal view returns (uint8, bytes32, bytes32) {
        return
            vm.sign(
                privateKey,
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        wrapper.domainSeparator(),
                        keccak256(
                            abi.encode(
                                TRANSFER_FROM_WITH_AUTHORIZATION_TYPEHASH,
                                relayer,
                                from,
                                to,
                                id,
                                validAfter,
                                validBefore,
                                nonce
                            )
                        )
                    )
                )
            );
    }

    /**
     * @notice Compute the storage location of `authorizationState[authorizer][nonce]`.
     * @param  from   address  The current owner of the NFT and authorizer.
     * @param  nonce  bytes32  Unique nonce.
     * @return        bytes32  Storage location.
     */
    function _getAuthorizationStateStorageLocation(
        address from,
        bytes32 nonce
    ) internal pure returns (bytes32) {
        return (
            // Storage location of `authorizationState[authorizer][nonce]`.
            // keccak256(nonceKey . keccak256(authorizerKey . mappingSlot)).
            keccak256(
                abi.encode(
                    nonce,
                    // Storage location of `authorizationState[authorizer]`.
                    // keccak256(authorizerKey . mappingSlot).
                    keccak256(
                        abi.encode(from, STORAGE_SLOT_AUTHORIZATION_STATE)
                    )
                )
            )
        );
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
                             transferFromWithAuthorization
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferFromWithAuthorizationNotTokenOwner() external {
        address msgSender = address(this);
        address from = TEST_ACCT;
        address to = address(1);
        uint256 id = 0;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = bytes32(uint256(1));
        uint8 v = 0;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);

        assertTrue(from != wrapper.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.NotTokenOwner.selector);

        wrapper.transferFromWithAuthorization(
            from,
            to,
            id,
            validAfter,
            validBefore,
            nonce,
            v,
            r,
            s
        );
    }

    function testCannotTransferFromWithAuthorizationUnsafeTokenRecipient()
        external
    {
        address msgSender = address(this);
        address from = TEST_ACCT;

        // Unsafe recipient.
        address to = address(0);

        uint256 id = 0;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = bytes32(uint256(1));
        uint8 v = 0;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);

        _mintWrap(from, id);

        assertEq(from, wrapper.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.UnsafeTokenRecipient.selector);

        wrapper.transferFromWithAuthorization(
            from,
            to,
            id,
            validAfter,
            validBefore,
            nonce,
            v,
            r,
            s
        );
    }

    function testCannotTransferFromWithAuthorizationInvalidAuthorizationValidAfter()
        external
    {
        address msgSender = address(this);
        address from = TEST_ACCT;
        address to = address(1);
        uint256 id = 0;

        // Timestamp that is in the future, beyond the ts of when `transferFromWithAuthorization` will be called.
        uint256 validAfter = block.timestamp + 1;

        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = bytes32(uint256(1));
        uint8 v = 0;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);

        _mintWrap(from, id);

        assertEq(from, wrapper.ownerOf(id));
        assertLt(block.timestamp, validAfter);

        vm.prank(msgSender);
        vm.expectRevert(WERC721.InvalidAuthorization.selector);

        wrapper.transferFromWithAuthorization(
            from,
            to,
            id,
            validAfter,
            validBefore,
            nonce,
            v,
            r,
            s
        );
    }

    function testCannotTransferFromWithAuthorizationInvalidAuthorizationValidBefore()
        external
    {
        address msgSender = address(this);
        address from = TEST_ACCT;
        address to = address(1);
        uint256 id = 0;
        uint256 validAfter = block.timestamp;

        // Timestamp that is in the past, before the ts of when `transferFromWithAuthorization` will be called.
        uint256 validBefore = block.timestamp - 1;

        bytes32 nonce = bytes32(uint256(1));
        uint8 v = 0;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);

        _mintWrap(from, id);

        assertEq(from, wrapper.ownerOf(id));
        assertGt(block.timestamp, validBefore);

        vm.prank(msgSender);
        vm.expectRevert(WERC721.InvalidAuthorization.selector);

        wrapper.transferFromWithAuthorization(
            from,
            to,
            id,
            validAfter,
            validBefore,
            nonce,
            v,
            r,
            s
        );
    }

    function testCannotTransferFromWithAuthorizationAuthorizationAlreadyUsed()
        external
    {
        address msgSender = address(this);
        address from = TEST_ACCT;
        address to = address(1);
        uint256 id = 0;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = bytes32(uint256(1));
        uint8 v = 0;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);

        _mintWrap(from, id);

        // Set `authorizationState[from][nonce]` to `true`.
        vm.store(
            address(wrapper),
            _getAuthorizationStateStorageLocation(from, nonce),
            bytes32(abi.encode(true))
        );

        assertTrue(wrapper.authorizationState(from, nonce));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.AuthorizationAlreadyUsed.selector);

        wrapper.transferFromWithAuthorization(
            from,
            to,
            id,
            validAfter,
            validBefore,
            nonce,
            v,
            r,
            s
        );
    }

    function testCannotTransferFromWithAuthorizationInvalidAuthorizationSignature()
        external
    {
        address msgSender = address(this);
        address from = TEST_ACCT;
        address to = address(1);
        uint256 id = 0;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = bytes32(uint256(1));
        uint8 v = 0;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);

        _mintWrap(from, id);

        assertFalse(wrapper.authorizationState(from, nonce));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.InvalidAuthorization.selector);

        wrapper.transferFromWithAuthorization(
            from,
            to,
            id,
            validAfter,
            validBefore,
            nonce,
            v,
            r,
            s
        );
    }

    function testTransferFromWithAuthorization() external {
        address msgSender = address(this);
        address from = TEST_ACCT;
        address to = address(1);
        uint256 id = 0;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = bytes32(uint256(1));
        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _signTransferFromWithAuthorizationDigest(
                TEST_ACCT_PRIV_KEY,
                msgSender,
                from,
                to,
                id,
                validAfter,
                validBefore,
                nonce
            );

        _mintWrap(from, id);

        assertEq(from, wrapper.ownerOf(id));
        assertFalse(wrapper.authorizationState(from, nonce));

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(wrapper));

        emit AuthorizationUsed(from, nonce);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(from, to, id);

        wrapper.transferFromWithAuthorization(
            from,
            to,
            id,
            validAfter,
            validBefore,
            nonce,
            v,
            r,
            s
        );

        assertEq(to, wrapper.ownerOf(id));
        assertEq(address(wrapper), collection.ownerOf(id));
        assertTrue(wrapper.authorizationState(from, nonce));
    }

    /*//////////////////////////////////////////////////////////////
                             cancelTransferFromAuthorization
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelTransferFromAuthorizationAuthorizationAlreadyUsed()
        external
    {
        address msgSender = TEST_ACCT;
        bytes32 nonce = bytes32(uint256(1));

        // Set `authorizationState[from][nonce]` to `true`.
        vm.store(
            address(wrapper),
            _getAuthorizationStateStorageLocation(msgSender, nonce),
            bytes32(abi.encode(true))
        );

        assertTrue(wrapper.authorizationState(msgSender, nonce));

        vm.prank(msgSender);
        vm.expectRevert(WERC721.AuthorizationAlreadyUsed.selector);

        wrapper.cancelTransferFromAuthorization(nonce);
    }

    function testCancelTransferFromAuthorization() external {
        address msgSender = TEST_ACCT;
        bytes32 nonce = bytes32(uint256(1));

        assertFalse(wrapper.authorizationState(msgSender, nonce));

        vm.prank(msgSender);
        vm.expectEmit(true, true, false, true, address(wrapper));

        emit AuthorizationCanceled(msgSender, nonce);

        wrapper.cancelTransferFromAuthorization(nonce);

        assertTrue(wrapper.authorizationState(msgSender, nonce));
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

        // Throws because the ERC721 token has not been minted.
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

    /*//////////////////////////////////////////////////////////////
                             multicall
    //////////////////////////////////////////////////////////////*/

    function testMulticallWrapTransferFrom() external {
        address msgSender = address(this);
        address wrapTo = address(this);
        address transferFromTo = address(1);
        uint256 id = 0;
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(WERC721.wrap.selector, wrapTo, id);
        data[1] = abi.encodeWithSelector(
            WERC721.transferFrom.selector,
            wrapTo,
            transferFromTo,
            id
        );

        vm.startPrank(msgSender);

        collection.mint(msgSender, id);
        collection.setApprovalForAll(address(wrapper), true);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(address(0), wrapTo, id);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(wrapTo, transferFromTo, id);

        wrapper.multicall(data);

        vm.stopPrank();

        assertEq(address(wrapper), collection.ownerOf(id));
        assertEq(transferFromTo, wrapper.ownerOf(id));
    }

    function testMulticallBatchWrapTransferFrom() external {
        address msgSender = address(this);
        address wrapTo = address(this);
        address transferFromTo = address(1);
        uint256[] memory ids = new uint256[](3);
        bytes[] memory data = new bytes[](6);

        for (uint256 i = 0; i < ids.length; ) {
            ids[i] = i;
            data[i] = abi.encodeWithSelector(WERC721.wrap.selector, wrapTo, i);

            // Add the `transferFrom` calls after all the `wrap` calls.
            data[i + 3] = abi.encodeWithSelector(
                WERC721.transferFrom.selector,
                wrapTo,
                transferFromTo,
                i
            );

            collection.mint(msgSender, i);

            unchecked {
                ++i;
            }
        }

        vm.startPrank(msgSender);

        collection.setApprovalForAll(address(wrapper), true);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(address(0), wrapTo, ids[0]);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(address(0), wrapTo, ids[1]);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(address(0), wrapTo, ids[2]);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(wrapTo, transferFromTo, ids[0]);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(wrapTo, transferFromTo, ids[1]);

        vm.expectEmit(true, true, true, true, address(wrapper));

        emit Transfer(wrapTo, transferFromTo, ids[2]);

        wrapper.multicall(data);

        vm.stopPrank();

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(wrapper), collection.ownerOf(ids[i]));
            assertEq(transferFromTo, wrapper.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
