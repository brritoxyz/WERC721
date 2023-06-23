// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {FrontPageBase} from "test/FrontPageBase.sol";
import {FrontPage} from "src/FrontPage.sol";

contract FrontPageTest is Test, FrontPageBase {
    event Mint();
    event BatchMint();

    /*//////////////////////////////////////////////////////////////
                             name
    //////////////////////////////////////////////////////////////*/

    function testName() external {
        assertEq(collection.name(), page.name());
    }

    /*//////////////////////////////////////////////////////////////
                             symbol
    //////////////////////////////////////////////////////////////*/

    function testSymbol() external {
        assertEq(collection.symbol(), page.symbol());
    }

    /*//////////////////////////////////////////////////////////////
                             tokenURI
    //////////////////////////////////////////////////////////////*/

    function testTokenURI(uint16 id) external {
        vm.assume(id < page.maxSupply());

        assertEq(collection.tokenURI(id), page.tokenURI(id));
    }

    /*//////////////////////////////////////////////////////////////
                             withdraw
    //////////////////////////////////////////////////////////////*/

    function testWithdraw() external {
        uint256 balanceBefore = address(page).balance;

        page.mint{value: MINT_PRICE}();

        assertEq(balanceBefore + MINT_PRICE, address(page).balance);

        uint256 creatorBalanceBeforeWithdraw = creator.balance;
        uint256 pageBalanceBeforeWithdraw = address(page).balance;

        page.withdraw();

        assertEq(
            creatorBalanceBeforeWithdraw + pageBalanceBeforeWithdraw,
            creator.balance
        );
        assertEq(0, address(page).balance);
    }

    /*//////////////////////////////////////////////////////////////
                             setBaseURI
    //////////////////////////////////////////////////////////////*/

    function testCannotSetBaseURIUnauthorized() external {
        assertTrue(collection.owner() != address(0));

        vm.prank(address(0));
        vm.expectRevert(Ownable.Unauthorized.selector);

        collection.setBaseURI("");
    }

    function testSetBaseURI() external {
        string memory baseURI = "https://example.com/";

        assertEq(address(this), collection.owner());
        assertEq("", collection.baseURI());

        collection.setBaseURI(baseURI);

        assertEq(baseURI, collection.baseURI());
    }

    /*//////////////////////////////////////////////////////////////
                             mint
    //////////////////////////////////////////////////////////////*/

    function testCannotMintSoldout() external {
        vm.store(address(page), bytes32(uint256(3)), bytes32(MAX_SUPPLY + 1));

        assertGt(page.nextId(), page.maxSupply());

        vm.expectRevert(FrontPage.Soldout.selector);

        page.mint();
    }

    function testCannotMintInvalidMsgValue(uint96 msgValue) external {
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

        emit Mint();

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

        for (uint256 i = 0; i < quantity; ) {
            assertEq(address(0), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }

        assertLe(page.nextId() + quantity, page.maxSupply());

        uint256 value = quantity * uint256(MINT_PRICE);

        vm.expectEmit(false, false, false, true, address(page));

        emit BatchMint();

        page.batchMint{value: value}(quantity);

        for (uint256 i = 0; i < quantity; ) {
            assertEq(address(this), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchMintFuzz(uint8 quantity) external {
        uint256 startingId = page.nextId();

        for (uint256 i = 0; i < quantity; ) {
            assertEq(address(0), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }

        assertLe(page.nextId() + quantity, page.maxSupply());

        uint256 value = quantity * uint256(MINT_PRICE);

        vm.expectEmit(false, false, false, true, address(page));

        emit BatchMint();

        page.batchMint{value: value}(quantity);

        for (uint256 i = 0; i < quantity; ) {
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
        uint256 id = page.nextId();

        assertEq(address(0), page.ownerOf(id));

        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.redeem(id);
    }

    function testRedeem() external {
        uint256 id = page.nextId();

        assertEq(address(0), page.ownerOf(id));

        page.mint{value: MINT_PRICE}();

        assertEq(address(this), page.ownerOf(id));

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);

        collection.ownerOf(id);

        page.redeem(id);

        assertEq(address(0), page.ownerOf(id));
        assertEq(address(this), collection.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             batchRedeem
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchRedeemUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(FrontPage.Unauthorized.selector);

        page.batchRedeem(ids);
    }

    function testBatchRedeem() external {
        for (uint256 i = 0; i < ids.length; ) {
            ids[i] = i + 1;

            assertEq(address(this), page.ownerOf(ids[i]));

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);

            collection.ownerOf(ids[i]);

            unchecked {
                ++i;
            }
        }

        page.batchRedeem(ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(0), page.ownerOf(ids[i]));
            assertEq(address(this), collection.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             multicall
    //////////////////////////////////////////////////////////////*/

    function testCannotMulticallInvalid() external {
        uint256 listingId = ids[0];
        uint96 price = 1 ether;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(
            FrontPage.list.selector,
            listingId,
            price
        );

        // Attempt to call `list` with the same ID, which will revert
        data[1] = abi.encodeWithSelector(
            FrontPage.list.selector,
            listingId,
            price
        );

        // Custom error will include the reverted call index
        vm.expectRevert(
            abi.encodeWithSelector(FrontPage.MulticallError.selector, 1)
        );

        page.multicall(data);
    }

    function testMulticall() external {
        uint256 listingId = ids[0];
        uint256 redeemId = ids[1];
        uint96 price = 1 ether;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(
            FrontPage.list.selector,
            listingId,
            price
        );
        data[1] = abi.encodeWithSelector(FrontPage.redeem.selector, redeemId);

        page.multicall(data);

        assertEq(address(page), page.ownerOf(listingId));
        assertEq(1, page.balanceOf(address(page), listingId));
        assertEq(address(this), collection.ownerOf(redeemId));
        assertEq(1, collection.balanceOf(address(this)));

        (address seller, uint96 listingPrice) = page.listings(listingId);

        assertEq(address(this), seller);
        assertEq(price, listingPrice);
    }
}
