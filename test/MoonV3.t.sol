// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Moon} from "src/MoonV3.sol";

contract DummyERC20 is ERC20("", "", 18) {}

contract DummyERC4626 is ERC4626(new DummyERC20(), "", "") {
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}

contract MoonTest is Test {
    using FixedPointMathLib for uint256;

    ERC20 private constant STAKER =
        ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ERC4626 private constant VAULT =
        ERC4626(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);
    bytes private constant UNAUTHORIZED_ERROR = bytes("UNAUTHORIZED");
    uint256 private constant FUZZ_ETH_AMOUNT = 0.00001 ether;

    // There may be minor discrepancies depending on staker and/or vault logic
    // so we allow a small margin of error (1 billionth of a percent)
    uint256 private constant ERROR_MARGIN_BASE = 1e9;
    uint256 private constant ERROR_MARGIN = 1;

    Moon private immutable moon;
    address private immutable moonAddr;
    uint256 private immutable maxRedemptionDuration;

    event SetStaker(address indexed msgSender, ERC20 staker);
    event SetVault(address indexed msgSender, ERC4626 vault);
    event DepositETH(address indexed msgSender, uint256 msgValue);
    event StakeETH(
        address indexed msgSender,
        uint256 balance,
        uint256 assets,
        uint256 shares
    );

    constructor() {
        moon = new Moon(STAKER, VAULT);
        moonAddr = address(moon);
        maxRedemptionDuration = moon.MAX_REDEMPTION_DURATION();

        assertEq(type(uint256).max, STAKER.allowance(moonAddr, address(VAULT)));
    }

    /*//////////////////////////////////////////////////////////////
                            setStaker
    //////////////////////////////////////////////////////////////*/

    function testCannotSetStakerUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(UNAUTHORIZED_ERROR);

        moon.setStaker(STAKER);
    }

    function testCannotSetStakerInvalidAddress() external {
        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.setStaker(ERC20(address(0)));
    }

    function testSetStaker() external {
        ERC20 staker = new DummyERC20();

        address msgSender = address(this);

        assertEq(msgSender, moon.owner());

        vm.expectEmit(true, false, false, true, moonAddr);

        emit SetStaker(msgSender, staker);

        moon.setStaker(staker);

        assertEq(address(staker), address(moon.staker()));
    }

    /*//////////////////////////////////////////////////////////////
                            setVault
    //////////////////////////////////////////////////////////////*/

    function testCannotSetVaultUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(UNAUTHORIZED_ERROR);

        moon.setVault(VAULT);
    }

    function testCannotSetVaultInvalidAddress() external {
        vm.expectRevert(Moon.InvalidAddress.selector);

        moon.setVault(ERC4626(address(0)));
    }

    function testSetVault() external {
        ERC4626 vault = new DummyERC4626();

        address msgSender = address(this);

        assertEq(msgSender, moon.owner());

        vm.expectEmit(true, false, false, true, moonAddr);

        emit SetVault(msgSender, vault);

        moon.setVault(vault);

        assertEq(address(vault), address(moon.vault()));
    }

    /*//////////////////////////////////////////////////////////////
                            depositETH
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositETHInvalidAmount() external {
        vm.expectRevert(Moon.InvalidAmount.selector);

        moon.depositETH{value: 0}();
    }

    function testDepositETH(
        address msgSender,
        uint32 amount,
        uint8 iterations
    ) external {
        vm.assume(msgSender != address(0));
        vm.assume(amount != 0);
        vm.assume(iterations != 0);
        vm.assume(iterations < 10);

        uint256 ethBalance;
        uint256 moonBalance;

        for (uint256 i; i < iterations; ) {
            uint256 ethAmount = uint256(amount) * FUZZ_ETH_AMOUNT;

            ethBalance += ethAmount;
            moonBalance += ethAmount;

            vm.deal(msgSender, ethAmount);
            vm.prank(msgSender);
            vm.expectEmit(true, false, false, true, moonAddr);

            emit DepositETH(msgSender, ethAmount);

            moon.depositETH{value: ethAmount}();

            assertEq(moonBalance, ethBalance);
            assertEq(moonBalance, moon.balanceOf(msgSender));
            assertEq(ethBalance, moonAddr.balance);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            stakeETH
    //////////////////////////////////////////////////////////////*/

    function testStakeETH(uint8 amount, uint8 iterations) external {
        vm.assume(amount != 0);
        vm.assume(iterations != 0);
        vm.assume(iterations < 10);

        uint256 totalAssets;
        uint256 totalShares;

        for (uint256 i; i < iterations; ) {
            uint256 ethAmount = uint256(amount) * FUZZ_ETH_AMOUNT;

            moon.depositETH{value: ethAmount}();

            (uint256 balance, uint256 assets, uint256 shares) = moon.stakeETH();

            totalAssets += assets;
            totalShares += shares;

            assertEq(ethAmount, balance);
            assertEq(totalShares, VAULT.balanceOf(moonAddr));

            unchecked {
                ++i;
            }
        }

        uint256 errorMargin = VAULT.maxWithdraw(moonAddr).mulDivDown(
            ERROR_MARGIN,
            ERROR_MARGIN_BASE
        );

        // Assets deposited should be greater than or equal to what's maximally
        // withdrawable by the vault (does not consider any exit fees)
        assertGe(totalAssets, VAULT.maxWithdraw(moonAddr) - errorMargin);
    }
}
