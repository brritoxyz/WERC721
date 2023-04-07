// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {Moon} from "src/Moon.sol";
import {Moonbase} from "test/Moonbase.sol";

contract MoonTest is Test, Moonbase {
    uint256 private immutable snapshotInterval;

    event SetFactory(address indexed factory);
    event AddMinter(address indexed factory, address indexed minter);

    constructor() {
        snapshotInterval = moon.SNAPSHOT_INTERVAL();
    }

    function _canSnapshot() private view returns (bool) {
        return moon.lastSnapshotAt() + snapshotInterval <= block.timestamp;
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
                                mint
    //////////////////////////////////////////////////////////////*/

    function testCannotMintNotMinter() external {
        vm.startPrank(address(0));
        vm.expectRevert(Moon.NotMinter.selector);

        moon.mint(address(this), 1);
    }

    function testCannotOverloadedMintNotMinter() external {
        vm.startPrank(address(0));
        vm.expectRevert(Moon.NotMinter.selector);

        moon.mint(address(this), address(this), 1);
    }

    function testCannotMintFactoryChanged() external {
        moon.setFactory(address(this));
        moon.addMinter(address(this));

        address to = address(this);
        uint256 amount = 1;

        assertEq(0, moon.balanceOf(to));

        moon.mint(to, amount);

        assertEq(amount, moon.balanceOf(to));

        moon.setFactory(address(factory));

        vm.expectRevert(Moon.NotMinter.selector);

        moon.mint(address(this), 1);
    }

    function testCannotOverloadedMintFactoryChanged() external {
        moon.setFactory(address(this));
        moon.addMinter(address(this));

        address buyer = testAccounts[0];
        address seller = testAccounts[1];
        uint256 amount = 1;

        assertEq(0, moon.balanceOf(buyer));
        assertEq(0, moon.balanceOf(seller));

        moon.mint(buyer, seller, amount);

        assertEq(amount, moon.balanceOf(buyer));
        assertEq(amount, moon.balanceOf(seller));

        moon.setFactory(address(factory));

        vm.expectRevert(Moon.NotMinter.selector);

        moon.mint(buyer, seller, 1);
    }

    function testMint(
        address[3] calldata to,
        uint80[3] calldata amount
    ) external {
        moon.setFactory(address(this));
        moon.addMinter(address(this));

        uint256 totalSupply;

        for (uint256 i; i < to.length; ) {
            address _to = to[i];
            uint256 _amount = amount[i];
            totalSupply += _amount;

            if (_to != address(0) && _amount != 0) {
                assertEq(0, moon.balanceOf(_to));

                moon.mint(_to, _amount);

                assertEq(_amount, moon.balanceOf(_to));
            }

            unchecked {
                ++i;
            }
        }

        assertEq(totalSupply, moon.totalSupply());
    }

    function testOverloadedMint(
        address[3] calldata buyers,
        address[3] calldata sellers,
        uint80[3] calldata amounts
    ) external {
        moon.setFactory(address(this));
        moon.addMinter(address(this));

        uint256 totalSupply;

        for (uint256 i; i < buyers.length; ) {
            address buyer = buyers[i];
            address seller = sellers[i];
            uint256 amount = amounts[i];

            // Multiply by 2, since we're minting MOON for both buyer and seller
            totalSupply += amount * 2;

            if (buyer != address(0) && seller != address(0) && amount != 0) {
                assertEq(0, moon.balanceOf(buyer));
                assertEq(0, moon.balanceOf(seller));

                moon.mint(buyer, seller, amount);

                assertEq(amount, moon.balanceOf(buyer));
                assertEq(amount, moon.balanceOf(seller));
            }

            unchecked {
                ++i;
            }
        }

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
}
