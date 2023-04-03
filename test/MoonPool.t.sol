// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import {MoonPool} from "src/MoonPool.sol";

contract MoonPoolTest is Test, ERC721TokenReceiver {
    ERC721 private constant AZUKI =
        ERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);
    address private constant AZUKI_OWNER =
        0x2aE6B0630EBb4D155C6e04fCB16840FFA77760AA;

    MoonPool private immutable pool;
    uint96 private immutable bpsBase;
    uint80 private immutable maxCollectionRoyalties;
    uint80 private immutable maxProtocolFees;
    address private immutable owner;

    // NFT IDs that are owned by the impersonated/pranked address
    uint256[] private initialNftIds = [0, 2, 7];

    event SetCollectionRoyalties(address indexed recipient, uint96 bps);
    event SetProtocolFees(address indexed recipient, uint96 bps);
    event List(address indexed seller, uint256 indexed id, uint96 price);
    event ListMany(address indexed seller, uint256[] ids, uint96[] prices);
    event Buy(
        address indexed buyer,
        address indexed seller,
        uint256 indexed id,
        uint96 price,
        uint256 totalFees
    );
    event BuyMany(
        address indexed buyer,
        uint256[] ids,
        uint256 totalPrice,
        uint256 totalCollectionRoyalties,
        uint256 totalProtocolFees
    );

    constructor() {
        vm.startPrank(AZUKI_OWNER);

        uint256 iLen = initialNftIds.length;

        // Transfer NFTs from owner to self
        for (uint256 i; i < iLen; ) {
            uint256 id = initialNftIds[i];

            assertTrue(AZUKI.ownerOf(id) == AZUKI_OWNER);

            AZUKI.safeTransferFrom(AZUKI_OWNER, address(this), id);

            assertTrue(AZUKI.ownerOf(id) == address(this));

            unchecked {
                ++i;
            }
        }

        vm.stopPrank();

        pool = new MoonPool(address(this), AZUKI);
        bpsBase = pool.BPS_BASE();
        maxCollectionRoyalties = pool.MAX_COLLECTION_ROYALTIES();
        maxProtocolFees = pool.MAX_PROTOCOL_FEES();
        owner = pool.owner();
    }

    /*///////////////////////////////////////////////////////////////
                        setCollectionRoyalties
    //////////////////////////////////////////////////////////////*/

    function testCannotSetCollectionRoyaltiesUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(bytes("UNAUTHORIZED"));

        pool.setCollectionRoyalties(address(this), 1000);
    }

    function testCannotSetCollectionRoyaltiesRecipientInvalidAddress()
        external
    {
        assertEq(address(this), owner);

        vm.expectRevert(MoonPool.InvalidAddress.selector);

        pool.setCollectionRoyalties(address(0), 1000);
    }

    function testCannotSetCollectionRoyaltiesBpsExceedsBase() external {
        assertEq(address(this), owner);

        address recipient = address(this);
        uint96 bps = bpsBase + 1;

        vm.expectRevert(MoonPool.InvalidNumber.selector);

        pool.setCollectionRoyalties(recipient, bps);
    }

    function testCannotSetCollectionRoyaltiesBpsExceedsMax() external {
        assertEq(address(this), owner);

        address recipient = address(this);
        uint96 bps = maxCollectionRoyalties + 1;

        vm.expectRevert(MoonPool.InvalidNumber.selector);

        pool.setCollectionRoyalties(recipient, bps);
    }

    function testSetCollectionRoyalties(uint96 bps) external {
        vm.assume(bps <= bpsBase);
        vm.assume(bps <= maxCollectionRoyalties);

        assertEq(address(this), owner);

        address recipient = address(this);
        (address recipientBefore, uint96 bpsBefore) = pool
            .collectionRoyalties();

        assertEq(address(0), recipientBefore);
        assertEq(0, bpsBefore);

        vm.expectEmit(true, false, false, true, address(pool));

        emit SetCollectionRoyalties(recipient, bps);

        pool.setCollectionRoyalties(recipient, bps);

        (address recipientAfter, uint96 bpsAfter) = pool.collectionRoyalties();

        assertEq(recipient, recipientAfter);
        assertEq(bps, bpsAfter);
    }

    /*///////////////////////////////////////////////////////////////
                            setProtocolFees
    //////////////////////////////////////////////////////////////*/

    function testCannotSetProtocolFeesUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(bytes("UNAUTHORIZED"));

        pool.setProtocolFees(address(this), 1000);
    }

    function testCannotSetProtocolFeesRecipientInvalidAddress() external {
        assertEq(address(this), owner);

        vm.expectRevert(MoonPool.InvalidAddress.selector);

        pool.setProtocolFees(address(0), 1000);
    }

    function testCannotSetProtocolFeesBpsExceedsBase() external {
        assertEq(address(this), owner);

        address recipient = address(this);
        uint96 bps = bpsBase + 1;

        vm.expectRevert(MoonPool.InvalidNumber.selector);

        pool.setProtocolFees(recipient, bps);
    }

    function testCannotSetProtocolFeesBpsExceedsMax() external {
        assertEq(address(this), owner);

        address recipient = address(this);
        uint96 bps = maxProtocolFees + 1;

        vm.expectRevert(MoonPool.InvalidNumber.selector);

        pool.setProtocolFees(recipient, bps);
    }

    function testSetProtocolFees(uint96 bps) external {
        vm.assume(bps <= bpsBase);
        vm.assume(bps <= maxProtocolFees);

        assertEq(address(this), owner);

        address recipient = address(this);
        (address recipientBefore, uint96 bpsBefore) = pool.protocolFees();

        assertEq(address(0), recipientBefore);
        assertEq(0, bpsBefore);

        vm.expectEmit(true, false, false, true, address(pool));

        emit SetProtocolFees(recipient, bps);

        pool.setProtocolFees(recipient, bps);

        (address recipientAfter, uint96 bpsAfter) = pool.protocolFees();

        assertEq(recipient, recipientAfter);
        assertEq(bps, bpsAfter);
    }
}
