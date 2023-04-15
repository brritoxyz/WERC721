// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Moon} from "src/Moon.sol";
import {Moonbase} from "test/Moonbase.sol";

contract MoonTest is Test, Moonbase {
    using FixedPointMathLib for uint256;

    uint128 private immutable userShareBase;
    uint128 private immutable userShare;
    address private immutable moonOwner;

    event SeedLiquidity(address indexed caller, uint256 amount);
    event SetFactory(address indexed caller, address indexed factory);
    event AddMinter(address indexed factory, address indexed minter);
    event DepositFees(
        address indexed minter,
        address indexed buyer,
        address indexed seller,
        uint256 amount
    );
    event ClaimFees(
        address indexed caller,
        uint256 amount,
        address indexed recipient
    );

    // For claiming fees
    receive() external payable {}

    constructor() {
        userShareBase = moon.USER_SHARE_BASE();
        userShare = moon.USER_SHARE();
        moonOwner = moon.owner();
    }

    function _getFactoryMinterHash(
        address minter
    ) private view returns (bytes32) {
        return keccak256(abi.encodePacked(moon.factory(), minter));
    }

    function _calculateUserRewards(
        uint256 amount
    ) private view returns (uint256) {
        return amount.mulDivDown(userShare, userShareBase) / 2;
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

        emit SetFactory(address(this), _factory);

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

        bytes32 factoryMinterHash = _getFactoryMinterHash(_minter);

        assertEq(address(this), moon.factory());
        assertFalse(moon.minters(factoryMinterHash));

        vm.expectEmit(true, true, false, true, address(moon));

        emit AddMinter(address(this), _minter);

        moon.addMinter(_minter);

        assertTrue(moon.minters(factoryMinterHash));
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

    function testDepositFees(uint80[3] calldata amounts) external {
        moon.setFactory(address(this));
        moon.addMinter(address(this));

        uint256 ownerRewards;
        uint256 totalAmount;

        for (uint256 i; i < testBuyers.length; ) {
            uint256 amount = amounts[i];

            if (amount != 0) {
                address buyer = testBuyers[i];
                address seller = testSellers[i];
                uint256 expectedUserRewards = _calculateUserRewards(amount);

                // Only the amount minted for the protocol team affects the supply
                ownerRewards += amount - (expectedUserRewards * 2);
                totalAmount += amount;

                assertEq(0, moon.balanceOf(buyer));
                assertEq(0, moon.balanceOf(seller));

                vm.expectEmit(true, true, false, true, address(moon));

                emit DepositFees(address(this), buyer, seller, amount);

                uint256 userRewards = moon.depositFees{value: amount}(
                    buyer,
                    seller
                );

                assertEq(expectedUserRewards, userRewards);
                assertEq(expectedUserRewards, moon.balanceOf(buyer));
                assertEq(expectedUserRewards, moon.balanceOf(seller));
                assertEq(ownerRewards, moon.balanceOf(moonOwner));
            }

            unchecked {
                ++i;
            }
        }

        assertEq(ownerRewards, moon.balanceOf(moonOwner));
        assertEq(totalAmount, moon.totalSupply());
        assertEq(totalAmount, address(moon).balance);
    }
}
