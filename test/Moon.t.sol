// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Moon} from "src/Moon.sol";
import {Moonbase} from "test/Moonbase.sol";

contract MoonTest is Test, Moonbase {
    using FixedPointMathLib for uint256;

    uint256 private immutable userShareBase;
    uint128 private immutable maxUserShare;
    uint128 private immutable minUserShare;
    uint256 private immutable maxSnapshotInterval;
    uint128 private immutable defaultUserShare;
    uint256 private immutable defaultSnapshotInterval;
    address private immutable moonOwner;

    event SetUserShare(uint96 userShare);
    event SetSnapshotInterval(uint64 snapshotInterval);
    event SetFactory(address indexed factory);
    event AddMinter(address indexed factory, address indexed minter);
    event DepositFees(
        address indexed buyer,
        address indexed seller,
        uint256 amount
    );

    constructor() {
        userShareBase = moon.USER_SHARE_BASE();
        maxUserShare = moon.MAX_USER_SHARE();
        minUserShare = moon.MIN_USER_SHARE();
        maxSnapshotInterval = moon.MAX_SNAPSHOT_INTERVAL();
        defaultUserShare = moon.userShare();
        defaultSnapshotInterval = moon.snapshotInterval();
        moonOwner = moon.owner();
    }

    function _canSnapshot() private view returns (bool) {
        return
            moon.lastSnapshotAt() + defaultSnapshotInterval <= block.timestamp;
    }

    function _calculateUserRewards(
        uint256 amount
    ) private view returns (uint256) {
        return amount.mulDivDown(moon.userShare(), userShareBase) / 2;
    }

    function _depositFeesAndMint(
        address buyer,
        address seller,
        uint256 amount
    ) private {
        if (address(this) != moon.factory()) {
            moon.setFactory(address(this));
            moon.addMinter(address(this));
        }

        uint256 ethBalanceBefore = address(moon).balance;
        uint256 feesBefore = moon.feesSinceLastSnapshot();

        moon.depositFees{value: amount}(buyer, seller);

        assertEq(ethBalanceBefore + amount, address(moon).balance);
        assertEq(feesBefore + amount, moon.feesSinceLastSnapshot());

        uint256 buyerBalanceBefore = moon.balanceOf(buyer);
        uint256 sellerBalanceBefore = moon.balanceOf(seller);
        uint256 buyerMintable = moon.mintable(buyer);
        uint256 sellerMintable = moon.mintable(seller);

        vm.prank(buyer);

        moon.mint(buyer);

        vm.prank(seller);

        moon.mint(seller);

        assertEq(0, moon.mintable(buyer));
        assertEq(0, moon.mintable(seller));
        assertEq(buyerBalanceBefore + buyerMintable, moon.balanceOf(buyer));
        assertEq(sellerBalanceBefore + sellerMintable, moon.balanceOf(seller));
    }

    /*//////////////////////////////////////////////////////////////
                            setUserShare
    //////////////////////////////////////////////////////////////*/

    function testCannotSetUserShareNotOwner() external {
        vm.prank(address(0));
        vm.expectRevert(NOT_OWNER_ERROR);

        moon.setUserShare(uint96(minUserShare));
    }

    function testCannotSetUserShareAboveMax() external {
        assertEq(address(this), moonOwner);

        uint96 aboveMax = uint96(maxUserShare) + 1;

        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.setUserShare(aboveMax);
    }

    function testCannotSetUserShareBelowMin() external {
        assertEq(address(this), moonOwner);

        uint96 belowMin = uint96(minUserShare) - 1;

        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.setUserShare(belowMin);
    }

    function testSetUserShare(uint96 _userShare) external {
        vm.assume(_userShare <= maxUserShare);
        vm.assume(_userShare >= minUserShare);
        vm.assume(_userShare != defaultUserShare);

        assertEq(address(this), moonOwner);

        vm.expectEmit(false, false, false, true, address(moon));

        emit SetUserShare(_userShare);

        moon.setUserShare(_userShare);

        assertEq(_userShare, moon.userShare());
    }

    /*//////////////////////////////////////////////////////////////
                            setSnapshotInterval
    //////////////////////////////////////////////////////////////*/

    function testCannotSetSnapshotIntervalNotOwner() external {
        vm.prank(address(0));
        vm.expectRevert(NOT_OWNER_ERROR);

        moon.setSnapshotInterval(1 hours);
    }

    function testCannotSetSnapshotIntervalZero() external {
        assertEq(address(this), moonOwner);

        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.setSnapshotInterval(0);
    }

    function testCannotSetSnapshotIntervalAboveMax() external {
        assertEq(address(this), moonOwner);

        uint64 aboveMax = uint64(maxSnapshotInterval) + 1;

        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.setSnapshotInterval(aboveMax);
    }

    function testSetSnapshotInterval(uint64 _snapshotInterval) external {
        vm.assume(_snapshotInterval != 0);
        vm.assume(_snapshotInterval <= maxSnapshotInterval);
        vm.assume(_snapshotInterval != defaultSnapshotInterval);

        assertEq(address(this), moonOwner);

        vm.expectEmit(false, false, false, true, address(moon));

        emit SetSnapshotInterval(_snapshotInterval);

        moon.setSnapshotInterval(_snapshotInterval);

        assertEq(_snapshotInterval, moon.snapshotInterval());
    }

    /*//////////////////////////////////////////////////////////////
                                setFactory
    //////////////////////////////////////////////////////////////*/

    function testCannotSetFactoryNotOwner() external {
        vm.prank(address(0));
        vm.expectRevert(NOT_OWNER_ERROR);

        moon.setFactory(address(this));
    }

    function testCannotSetFactoryInvalidAddress() external {
        assertEq(address(this), moonOwner);

        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.setFactory(address(0));
    }

    function testSetFactory(address _factory) external {
        vm.assume(_factory != address(0));
        vm.assume(_factory != address(factory));

        assertEq(address(this), moonOwner);
        assertFalse(_factory == moon.factory());

        vm.expectEmit(true, false, false, true, address(moon));

        emit SetFactory(_factory);

        moon.setFactory(_factory);

        assertEq(_factory, moon.factory());
    }

    /*//////////////////////////////////////////////////////////////
                                addMinter
    //////////////////////////////////////////////////////////////*/

    function testCannotAddMinterNotFactory() external {
        vm.prank(address(0));
        vm.expectRevert(Moon.NotFactory.selector);

        moon.addMinter(address(this));
    }

    function testCannotAddMinterInvalidAddress() external {
        moon.setFactory(address(this));

        assertEq(address(this), moon.factory());

        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.addMinter(address(0));
    }

    function testAddMinter(address _minter) external {
        vm.assume(_minter != address(0));

        moon.setFactory(address(this));

        assertEq(address(this), moon.factory());
        assertFalse(moon.minters(address(this), _minter));

        vm.expectEmit(true, true, false, true, address(moon));

        emit AddMinter(address(this), _minter);

        moon.addMinter(_minter);

        assertTrue(moon.minters(address(this), _minter));
    }

    /*//////////////////////////////////////////////////////////////
                            depositFees
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositFeesNotMinter() external {
        vm.startPrank(address(0));
        vm.expectRevert(Moon.NotMinter.selector);

        moon.depositFees{value: 1}(address(this), address(this));
    }

    function testCannotDepositFeesFactoryChanged() external {
        moon.setFactory(address(this));
        moon.addMinter(address(this));

        address buyer = testAccounts[0];
        address seller = testAccounts[1];
        uint256 amount = 1;

        // Functions properly until the factory changes
        moon.depositFees{value: amount}(buyer, seller);

        moon.setFactory(address(factory));

        vm.expectRevert(Moon.NotMinter.selector);

        moon.depositFees{value: amount}(buyer, seller);
    }

    function testDepositFees(
        address[3] calldata buyers,
        address[3] calldata sellers,
        uint80[3] calldata amounts
    ) external {
        moon.setFactory(address(this));
        moon.addMinter(address(this));

        uint256 teamRewards;
        uint256 totalSupply;
        uint256 totalMintable;
        uint256 totalAmount;

        for (uint256 i; i < buyers.length; ) {
            address buyer = buyers[i];
            address seller = sellers[i];
            uint256 amount = amounts[i];
            uint256 userRewards = _calculateUserRewards(amount);
            uint256 _teamRewards = amount - (userRewards * 2);

            // Only the amount minted for the protocol team affects the supply
            teamRewards += _teamRewards;
            totalSupply += _teamRewards;
            totalMintable += userRewards * 2;
            totalAmount += amount;

            if (buyer != address(0) && seller != address(0) && amount != 0) {
                assertEq(0, moon.mintable(buyer));
                assertEq(0, moon.mintable(seller));

                vm.expectEmit(true, true, false, true, address(moon));

                emit DepositFees(buyer, seller, amount);

                uint256 _userRewards = moon.depositFees{value: amount}(
                    buyer,
                    seller
                );

                assertEq(userRewards, _userRewards);
                assertEq(userRewards, moon.mintable(buyer));
                assertEq(userRewards, moon.mintable(seller));
            }

            unchecked {
                ++i;
            }
        }

        assertEq(teamRewards, moon.balanceOf(moonOwner));
        assertEq(totalSupply, moon.totalSupply());

        // 1 MOON (mintable and minted) = 1 ETH
        assertEq(totalMintable + teamRewards, totalAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                snapshot
    //////////////////////////////////////////////////////////////*/

    function testCannotSnapshotTooSoon() external {
        uint256 lastSnapshotAt = moon.lastSnapshotAt();

        assertTrue(_canSnapshot());

        uint256 snapshotId = moon.snapshot();

        assertEq(1, snapshotId);

        lastSnapshotAt = moon.lastSnapshotAt();

        assertFalse(_canSnapshot());

        snapshotId = moon.snapshot();

        // Snapshot ID remains unchanged
        assertEq(1, snapshotId);
    }

    function testSnapshot(uint8 iterations) external {
        vm.assume(iterations != 0);

        // Initialize with a snapshot
        uint256 snapshotId = moon.snapshot();

        for (uint256 i; i < iterations; ) {
            // Snapshot cannot be taken until adequate time elapses
            assertFalse(_canSnapshot());

            vm.warp(block.timestamp + defaultSnapshotInterval);

            // Snapshot can now be taken
            assertTrue(_canSnapshot());

            uint256 _snapshotId = moon.snapshot();

            unchecked {
                // Increment local snapshot ID tracker and compare
                assertEq(++snapshotId, _snapshotId);

                ++i;
            }
        }
    }

    function testSnapshotWithFeesBalancesSupply() external {
        address buyer = testAccounts[0];
        address seller = testAccounts[1];

        _depositFeesAndMint(buyer, seller, 1 ether);

        assertEq(0, moon.getSnapshotId());
        assertEq(0, moon.lastSnapshotAt());

        uint256 buyerBalanceBeforeSnapshot = moon.balanceOf(buyer);
        uint256 sellerBalanceBeforeSnapshot = moon.balanceOf(seller);
        uint256 ownerBalanceBeforeSnapshot = moon.balanceOf(moonOwner);
        uint256 totalSupplyBeforeSnapshot = moon.totalSupply();
        uint256 feesBeforeSnapshot = moon.feesSinceLastSnapshot();
        uint256 snapshotId = moon.snapshot();

        // Should now be zero
        assertEq(0, moon.feesSinceLastSnapshot());

        // Affect balances, supply, and fees, to verify snapshot unchanged
        _depositFeesAndMint(buyer, seller, 1 ether);

        assertEq(
            buyerBalanceBeforeSnapshot,
            moon.balanceOfAt(buyer, snapshotId)
        );
        assertEq(
            sellerBalanceBeforeSnapshot,
            moon.balanceOfAt(seller, snapshotId)
        );
        assertEq(
            ownerBalanceBeforeSnapshot,
            moon.balanceOfAt(moonOwner, snapshotId)
        );
        assertEq(totalSupplyBeforeSnapshot, moon.totalSupplyAt(snapshotId));
        assertEq(feesBeforeSnapshot, moon.feeSnapshots(snapshotId));
    }
}
