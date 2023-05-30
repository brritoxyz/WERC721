// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FrontPageBase} from "test/FrontPageBase.sol";
import {FrontPage} from "src/FrontPage.sol";

contract FrontPageTest is Test, FrontPageBase {
    event Mint(uint256 id);
    event BatchMint(uint256 startingId, uint256 quantity);

    /*//////////////////////////////////////////////////////////////
                             mint
    //////////////////////////////////////////////////////////////*/

    function testCannotMintSoldout() external {
        vm.store(address(page), bytes32(uint256(3)), bytes32(MAX_SUPPLY + 1));

        assertGt(page.nextId(), page.maxSupply());

        vm.expectRevert(FrontPage.Soldout.selector);

        page.mint();
    }

    function testCannotMintInvalidMsgValue(uint256 msgValue) external {
        vm.assume(msgValue != MINT_PRICE);
        vm.deal(address(this), msgValue);
        vm.expectRevert(FrontPage.InvalidMsgValue.selector);

        page.mint{value: msgValue}();
    }

    function testMint() external {
        assertLe(page.nextId(), page.maxSupply());

        uint256 nextId = page.nextId();
        uint256 pageBalanceBefore = address(page).balance;

        assertEq(address(0), page.ownerOf(nextId));

        uint256 value = MINT_PRICE;

        vm.expectEmit(false, false, false, true, address(page));

        emit Mint(nextId);

        page.mint{value: value}();

        assertEq(address(this), page.ownerOf(nextId));
        assertEq(pageBalanceBefore + value, address(page).balance);
        assertEq(nextId + 1, page.nextId());
    }

    /*//////////////////////////////////////////////////////////////
                             batchMint
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchMintInvalidMsgValue(uint256 quantity) external {
        vm.assume(quantity != 0);
        vm.assume(quantity <= MAX_SUPPLY);

        uint256 value = (quantity * MINT_PRICE) - 1;

        vm.expectRevert(FrontPage.InvalidMsgValue.selector);

        page.batchMint{value: value}(quantity);
    }

    function testCannotBatchMintSoldout(uint48 quantity) external {
        vm.assume(quantity != 0);
        vm.store(address(page), bytes32(uint256(3)), bytes32(MAX_SUPPLY));

        uint256 value = uint256(quantity) * uint256(MINT_PRICE);

        vm.deal(address(this), value);
        vm.expectRevert(FrontPage.Soldout.selector);

        page.batchMint{value: value}(quantity);
    }

    function testBatchMint() external {
        uint256 quantity = 5;
        uint256 startingId = page.nextId();

        for (uint256 i; i < quantity; ) {
            assertEq(address(0), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }

        assertLe(page.nextId() + quantity, page.maxSupply());

        uint256 value = quantity * uint256(MINT_PRICE);

        vm.expectEmit(false, false, false, true, address(page));

        emit BatchMint(startingId, quantity);

        page.batchMint{value: value}(quantity);

        for (uint256 i; i < quantity; ) {
            assertEq(address(this), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchMintFuzz(uint8 quantity) external {
        uint256 startingId = page.nextId();

        for (uint256 i; i < quantity; ) {
            assertEq(address(0), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }

        assertLe(page.nextId() + quantity, page.maxSupply());

        uint256 value = quantity * uint256(MINT_PRICE);

        vm.expectEmit(false, false, false, true, address(page));

        emit BatchMint(startingId, quantity);

        page.batchMint{value: value}(quantity);

        for (uint256 i; i < quantity; ) {
            assertEq(address(this), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             redeem
    //////////////////////////////////////////////////////////////*/

    function testCannotRedeemUnauthorized() external {
        uint256 id = 1;

        assertEq(address(0), page.ownerOf(id));

        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.redeem(id);
    }

    function testRedeem() external {
        uint256 id = page.nextId();

        assertEq(address(0), page.ownerOf(id));

        page.mint{value: MINT_PRICE}();

        assertEq(address(this), page.ownerOf(id));

        vm.expectRevert("NOT_MINTED");

        collection.ownerOf(id);

        page.redeem(1);

        assertEq(address(0), page.ownerOf(id));
        assertEq(address(this), collection.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             batchRedeem
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchRedeemUnauthorized() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = page.nextId();

        assertEq(address(0), page.ownerOf(ids[0]));

        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.batchRedeem(ids);
    }

    function testBatchRedeem() external {
        uint256[] memory ids = new uint256[](5);

        page.batchMint{value: MINT_PRICE * ids.length}(ids.length);

        for (uint256 i; i < ids.length; ) {
            ids[i] = i + 1;

            assertEq(address(this), page.ownerOf(ids[i]));

            vm.expectRevert("NOT_MINTED");

            collection.ownerOf(ids[i]);

            unchecked {
                ++i;
            }
        }

        page.batchRedeem(ids);

        for (uint256 i; i < ids.length; ) {
            assertEq(address(0), page.ownerOf(ids[i]));
            assertEq(address(this), collection.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
