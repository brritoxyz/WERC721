// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Moon} from "src/Moon.sol";
import {Moonbase} from "test/Moonbase.sol";

contract MoonTest is Test, Moonbase {
    using FixedPointMathLib for uint256;

    uint256 private immutable snapshotInterval;
    uint256 private immutable userShareBase;
    uint128 private immutable maxUserShare;
    uint128 private immutable minUserShare;
    uint128 private immutable defaultUserShare;

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
        snapshotInterval = moon.snapshotInterval();
        userShareBase = moon.USER_SHARE_BASE();
        maxUserShare = moon.MAX_USER_SHARE();
        minUserShare = moon.MIN_USER_SHARE();
        defaultUserShare = moon.userShare();
    }

    function _canSnapshot() private view returns (bool) {
        return moon.lastSnapshotAt() + snapshotInterval <= block.timestamp;
    }

    function _calculateUserRewards(
        uint256 amount
    ) private view returns (uint256) {
        return amount.mulDivDown(moon.userShare(), userShareBase) / 2;
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
        assertEq(address(this), moon.owner());

        uint96 aboveMax = uint96(maxUserShare) + 1;

        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.setUserShare(aboveMax);
    }

    function testCannotSetUserShareBelowMin() external {
        assertEq(address(this), moon.owner());

        uint96 belowMin = uint96(minUserShare) - 1;

        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.setUserShare(belowMin);
    }

    function testSetUserShare(uint96 _userShare) external {
        vm.assume(_userShare < maxUserShare);
        vm.assume(_userShare > minUserShare);
        vm.assume(_userShare != defaultUserShare);

        assertEq(address(this), moon.owner());

        vm.expectEmit(false, false, false, true, address(moon));

        emit SetUserShare(_userShare);

        moon.setUserShare(_userShare);

        assertEq(_userShare, moon.userShare());
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
        assertEq(address(this), moon.owner());

        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.setFactory(address(0));
    }

    function testSetFactory(address _factory) external {
        vm.assume(_factory != address(0));
        vm.assume(_factory != address(factory));

        assertEq(address(this), moon.owner());
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

        for (uint256 i; i < buyers.length; ) {
            address buyer = buyers[i];
            address seller = sellers[i];
            uint256 amount = amounts[i];
            uint256 userRewards = _calculateUserRewards(amount);
            uint256 _teamRewards = amount - (userRewards * 2);

            // Only the amount minted for the protocol team affects the supply
            teamRewards += _teamRewards;
            totalSupply += _teamRewards;

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

        assertEq(teamRewards, moon.balanceOf(moon.owner()));
        assertEq(totalSupply, moon.totalSupply());
    }

    /*//////////////////////////////////////////////////////////////
                                snapshot
    //////////////////////////////////////////////////////////////*/

    function testCannotSnapshotTooSoon() external {
        uint256 lastSnapshotAt = moon.lastSnapshotAt();

        assertTrue(_canSnapshot());

        moon.snapshot();

        assertEq(1, moon.getSnapshotId());

        lastSnapshotAt = moon.lastSnapshotAt();

        assertFalse(_canSnapshot());

        moon.snapshot();

        // Snapshot ID remains unchanged
        assertEq(1, moon.getSnapshotId());
    }

    function testSnapshot(uint8 iterations) external {
        vm.assume(iterations != 0);

        uint256 snapshotId = moon.getSnapshotId();

        for (uint256 i; i < iterations; ) {
            vm.warp(block.timestamp + snapshotInterval);

            assertTrue(_canSnapshot());

            moon.snapshot();

            unchecked {
                assertEq(++snapshotId, moon.getSnapshotId());

                ++i;
            }
        }
    }
}
