// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Page} from "src/Page.sol";
import {PageBase} from "test/PageBase.sol";

contract PageExchangeTest is Test, PageBase {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );
    event Initialize(address owner, ERC721 collection, address tipRecipient);
    event SetTipRecipient(address tipRecipient);
    event List(uint256 id);
    event Edit(uint256 id);
    event Cancel(uint256 id);
    event Buy(uint256 id);
    event BatchList(uint256[] ids);
    event BatchEdit(uint256[] ids);
    event BatchCancel(uint256[] ids);
    event BatchBuy(uint256[] ids);

    function _calculateTransferValues(
        uint256 price,
        uint256 tip
    ) private view returns (uint256 priceETH, uint256 tipETH) {
        return (price * valueDenom, tip * valueDenom);
    }

    function _calculateListingValues(
        uint256 price,
        uint256 tip
    ) private view returns (uint256 priceETH, uint256 sellerProceeds) {
        priceETH = price * valueDenom;
        sellerProceeds = priceETH - (tip * valueDenom);
    }

    /*//////////////////////////////////////////////////////////////
                             _calculateListingValues
    //////////////////////////////////////////////////////////////*/

    function testCalculateListingValues(
        uint48 price,
        uint48 tip
    ) external view {
        vm.assume(tip <= price);

        // Should never revert
        _calculateListingValues(price, tip);
    }

    /*//////////////////////////////////////////////////////////////
                             tokenURI
    //////////////////////////////////////////////////////////////*/

    function testTokenURI() external {
        uint256 id = ids[0];
        string memory collectionURI = LLAMA.tokenURI(id);

        assertEq(
            keccak256(abi.encodePacked(collectionURI)),
            keccak256(abi.encodePacked(page.tokenURI(id)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             setTipRecipient
    //////////////////////////////////////////////////////////////*/

    function testCannotSetTipRecipientZero() external {
        vm.expectRevert(Page.Zero.selector);

        page.setTipRecipient(payable(address(0)));
    }

    function testCannotSetTipRecipientUnauthorized() external {
        address caller = accounts[0];

        assertTrue(caller != page.owner());

        vm.prank(caller);
        vm.expectRevert("UNAUTHORIZED");

        page.setTipRecipient(payable(address(0)));
    }

    function testSetTipRecipient() external {
        address caller = address(this);
        address payable tipRecipient = payable(accounts[0]);

        assertEq(caller, page.owner());
        assertTrue(tipRecipient != page.tipRecipient());

        vm.expectEmit(false, false, false, true, address(page));

        emit SetTipRecipient(tipRecipient);

        page.setTipRecipient(tipRecipient);

        assertEq(tipRecipient, page.tipRecipient());
    }

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testDeposit() external {
        uint256 id;
        address recipient;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            recipient = accounts[i];

            assertEq(address(this), LLAMA.ownerOf(id));
            assertEq(address(0), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.expectEmit(true, true, true, true, address(LLAMA));

            emit Transfer(address(this), address(page), id);

            page.deposit(id, recipient);

            assertEq(address(page), LLAMA.ownerOf(id));
            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchDeposit
    //////////////////////////////////////////////////////////////*/

    function testBatchDeposit() external {
        address recipient = accounts[0];
        uint256[] memory amounts = new uint256[](ids.length);

        // For batching the balance check
        address[] memory batchBalanceRecipient = new address[](ids.length);

        for (uint256 i; i < ids.length; ) {
            batchBalanceRecipient[i] = recipient;
            amounts[i] = ONE;

            unchecked {
                ++i;
            }
        }

        page.batchDeposit(ids, recipient);

        uint256[] memory balances = page.balanceOfBatch(
            batchBalanceRecipient,
            ids
        );

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];

            assertEq(1, balances[i]);
            assertEq(recipient, page.ownerOf(id));
            assertEq(address(page), LLAMA.ownerOf(id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             withdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotWithdrawRecipientZero() external {
        address recipient = address(0);

        page.deposit(ids[0], accounts[0]);

        vm.prank(accounts[0]);
        vm.expectRevert();

        page.withdraw(ids[0], recipient);
    }

    function testCannotWithdrawMsgSenderUnauthorized() external {
        address msgSender = accounts[0];
        uint256 id = ids[0];
        address recipient = accounts[0];

        vm.prank(msgSender);
        vm.expectRevert(Page.Unauthorized.selector);

        page.withdraw(id, recipient);
    }

    function testWithdraw() external {
        uint256 id;
        address recipient;

        // Deposit the NFTs and mint derivative tokens for recipients
        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            recipient = accounts[i];

            page.deposit(id, recipient);

            assertEq(address(page), LLAMA.ownerOf(id));
            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }

        address owner;

        // Withdraw the NFTs by redeeming the derivative tokens as their owners
        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            owner = accounts[i];

            vm.prank(owner);
            vm.expectEmit(true, true, true, true, address(LLAMA));

            emit Transfer(address(page), recipient, id);

            page.withdraw(id, recipient);

            assertEq(recipient, LLAMA.ownerOf(id));
            assertEq(address(0), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchWithdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchWithdrawRecipientZero() external {
        uint256[] memory withdrawIds = new uint256[](1);
        address recipient = address(0);

        page.batchDeposit(ids, accounts[0]);

        vm.prank(accounts[0]);
        vm.expectRevert();

        page.batchWithdraw(withdrawIds, recipient);
    }

    function testCannotBatchWithdrawMsgSenderUnauthorized() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        vm.prank(address(this));
        vm.expectRevert(Page.Unauthorized.selector);

        page.batchWithdraw(ids, address(this));
    }

    function testBatchWithdraw() external {
        address recipient = accounts[0];
        uint256[] memory amounts = new uint256[](ids.length);

        // For batching the balance check
        address[] memory batchBalanceRecipient = new address[](ids.length);

        for (uint256 i; i < ids.length; ) {
            batchBalanceRecipient[i] = recipient;
            amounts[i] = ONE;

            unchecked {
                ++i;
            }
        }

        page.batchDeposit(ids, recipient);

        uint256[] memory balances = page.balanceOfBatch(
            batchBalanceRecipient,
            ids
        );

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];

            assertEq(1, balances[i]);
            assertEq(recipient, page.ownerOf(id));
            assertEq(address(page), LLAMA.ownerOf(id));

            unchecked {
                ++i;
            }
        }

        address withdrawRecipient = address(this);

        vm.prank(recipient);

        page.batchWithdraw(ids, withdrawRecipient);

        balances = page.balanceOfBatch(batchBalanceRecipient, ids);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];

            assertEq(0, balances[i]);
            assertEq(address(0), page.ownerOf(id));
            assertEq(withdrawRecipient, LLAMA.ownerOf(id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             list
    //////////////////////////////////////////////////////////////*/

    function testCannotListUnauthorized() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint48 price = 100_000;
        uint48 tip = 1_000;

        // Mint a derivative token for a recipient and attempt to list on their behalf
        page.deposit(id, recipient);

        assertEq(recipient, page.ownerOf(id));
        assertEq(1, page.balanceOf(recipient, id));

        vm.expectRevert(Page.Unauthorized.selector);

        page.list(id, price, tip);
    }

    function testCannotListPriceLessThanTipInvalid() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint48 price = 100_000;

        // Price cannot be less than tip
        uint48 tip = price + 1;

        assertLt(price, tip);

        // Mint a derivative token for a recipient and attempt to list on their behalf
        page.deposit(id, recipient);

        vm.prank(recipient);
        vm.expectRevert(Page.Invalid.selector);

        page.list(id, price, tip);
    }

    function testCannotListPriceZero() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint48 price = 0;
        uint48 tip = 1_000;

        // Mint a derivative token for a recipient and attempt to list on their behalf
        page.deposit(id, recipient);

        assertEq(recipient, page.ownerOf(id));
        assertEq(1, page.balanceOf(recipient, id));

        // Call `list` as the recipient to ensure that they are authorized to sell
        vm.prank(recipient);
        vm.expectRevert(Page.Zero.selector);

        page.list(id, price, tip);
    }

    function testList(uint48 price, uint48 tip) external {
        vm.assume(price != 0);
        vm.assume(tip <= price);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];

            page.deposit(id, recipient);

            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));
            assertEq(0, page.balanceOf(address(page), id));

            vm.prank(recipient);
            vm.expectEmit(false, false, false, true, address(page));

            emit List(id);

            page.list(id, price, tip);

            (address seller, uint48 listingPrice, uint48 listingTip) = page
                .listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(recipient, seller);
            assertEq(price, listingPrice);
            assertEq(tip, listingTip);
            assertGe(listingPrice, listingTip);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             edit
    //////////////////////////////////////////////////////////////*/

    function testCannotEditPriceZero() external {
        uint256 id = ids[0];
        uint48 price = 0;

        vm.expectRevert(Page.Zero.selector);

        page.edit(id, price);
    }

    function testCannotEditUnauthorized() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint48 price = 100_000;
        uint48 tip = 1_000;
        uint48 newPrice = 200;

        page.deposit(id, recipient);

        vm.prank(recipient);

        page.list(id, price, tip);

        vm.expectRevert(Page.Unauthorized.selector);

        page.edit(id, newPrice);
    }

    function testCannotEditNewPriceLessThanTip() external {
        uint256 id = ids[0];
        uint48 price = 100_000;
        uint48 tip = 1_000;
        uint48 newPrice = 200;

        page.deposit(id, address(this));
        page.list(id, price, tip);

        assertLt(newPrice, tip);

        vm.expectRevert(Page.Invalid.selector);

        page.edit(id, newPrice);
    }

    function testEdit(uint48 price, uint48 tip, uint48 newPrice) external {
        vm.assume(price != 0);
        vm.assume(tip <= price);
        vm.assume(newPrice != 0);
        vm.assume(newPrice != price);
        vm.assume(newPrice >= tip);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price, tip);

            (address seller, uint48 listingPrice, uint48 listingTip) = page
                .listings(id);

            assertEq(recipient, seller);
            assertEq(price, listingPrice);
            assertGe(listingPrice, listingTip);

            vm.prank(recipient);
            vm.expectEmit(false, false, false, true, address(page));

            emit Edit(id);

            page.edit(id, newPrice);

            (seller, listingPrice, listingTip) = page.listings(id);

            // Verify that the updated listing has the same seller, different price
            assertEq(recipient, seller);
            assertEq(newPrice, listingPrice);
            assertGe(listingPrice, listingTip);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             cancel
    //////////////////////////////////////////////////////////////*/

    function testCannotCancelUnauthorized() external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint48 price = 100_000;
        uint48 tip = 1_000;

        page.deposit(id, recipient);

        vm.prank(recipient);

        page.list(id, price, tip);

        vm.expectRevert(Page.Unauthorized.selector);

        page.cancel(id);
    }

    function testCancel() external {
        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint48 price = 100_000;
            uint48 tip = 1_000;

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price, tip);

            assertEq(address(page), page.ownerOf(id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.prank(recipient);
            vm.expectEmit(false, false, false, true, address(page));

            emit Cancel(id);

            page.cancel(id);

            assertEq(recipient, page.ownerOf(id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(1, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             buy
    //////////////////////////////////////////////////////////////*/

    function testCannotBuyMsgValueInsufficient(bool shouldList) external {
        uint256 id = ids[0];
        address recipient = accounts[0];
        uint48 price = 100_000;
        uint48 tip = 1_000;

        // Reverts with `Insufficient` if msg.value is insufficient or if not listed
        if (shouldList) {
            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price, tip);

            vm.expectRevert(Page.Insufficient.selector);
        } else {
            vm.expectRevert(Page.Nonexistent.selector);
        }

        // Attempt to buy with msg.value less than price
        page.buy{value: price - 1}(id);
    }

    function testBuy(uint48 price, uint48 tip) external {
        vm.assume(price != 0);
        vm.assume(tip < price);

        uint256 id;
        address recipient;
        uint256 priceETH;
        uint256 tipETH;
        address seller;
        uint48 listingPrice;
        uint48 listingTip;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            recipient = accounts[i];

            // Retrieve the ETH amounts for determining the sufficient msg.value
            // and to also check that the proper amounts were received by all parties
            (priceETH, tipETH) = _calculateTransferValues(price, tip);

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price, tip);

            (seller, listingPrice, listingTip) = page.listings(id);
            uint256 sellerBalanceBefore = recipient.balance;
            uint256 tipRecipientBalanceBefore = TIP_RECIPIENT.balance;

            vm.expectEmit(false, false, false, true, address(page));

            emit Buy(id);

            page.buy{value: priceETH}(id);

            (seller, listingPrice, listingTip) = page.listings(id);

            assertEq(address(0), seller);
            assertEq(0, listingPrice);
            assertEq(0, listingTip);
            assertEq(address(this), page.ownerOf(id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(1, page.balanceOf(address(this), id));
            assertEq(
                sellerBalanceBefore + priceETH - tipETH,
                recipient.balance
            );
            assertEq(tipRecipientBalanceBefore + tipETH, TIP_RECIPIENT.balance);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchList
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchListMismatchedArrayInvalid() external {
        uint48[] memory prices = new uint48[](0);
        uint48[] memory tips = new uint48[](ids.length);

        vm.expectRevert(stdError.indexOOBError);

        page.batchList(ids, prices, tips);

        prices = new uint48[](ids.length);
        tips = new uint48[](0);

        vm.expectRevert(stdError.indexOOBError);

        page.batchList(ids, prices, tips);
    }

    function testBatchList(uint48 price, uint48 tip) external {
        vm.assume(price != 0);
        vm.assume(tip < price);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = price;
            tips[i] = tip;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchList(ids);

        page.batchList(ids, prices, tips);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint48 listingPrice, uint48 listingTip) = page
                .listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(recipient, seller);
            assertEq(prices[i], listingPrice);
            assertEq(tips[i], listingTip);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchEdit
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchEditMismatchedArrayInvalid() external {
        uint48[] memory newPrices = new uint48[](0);

        vm.expectRevert(stdError.indexOOBError);

        page.batchEdit(ids, newPrices);
    }

    function testCannotBatchEditNewPriceZero() external {
        uint48[] memory newPrices = new uint48[](ids.length);

        vm.expectRevert(Page.Zero.selector);

        page.batchEdit(ids, newPrices);
    }

    function testCannotBatchEditUnauthorized() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);
        uint48[] memory newPrices = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000;
            tips[i] = 1_000;
            newPrices[i] = 200_000;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        vm.expectRevert(Page.Unauthorized.selector);

        page.batchEdit(ids, newPrices);
    }

    function testBatchEdit(uint48 price, uint48 tip, uint48 newPrice) external {
        vm.assume(price != 0);
        vm.assume(tip <= price);
        vm.assume(newPrice != 0);
        vm.assume(newPrice != price);
        vm.assume(newPrice >= tip);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);
        uint48[] memory newPrices = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = price;
            tips[i] = tip;
            newPrices[i] = newPrice;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        vm.prank(recipient);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchEdit(ids);

        page.batchEdit(ids, newPrices);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint48 listingPrice, uint48 listingTip) = page
                .listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(recipient, seller);
            assertEq(newPrices[i], listingPrice);
            assertEq(tips[i], listingTip);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchCancel
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchCancelUnauthorized() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000;
            tips[i] = 1_000;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        vm.expectRevert(Page.Unauthorized.selector);

        page.batchCancel(ids);
    }

    function testBatchCancel() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000;
            tips[i] = 1_000;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        vm.prank(recipient);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchCancel(ids);

        page.batchCancel(ids);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            (address seller, uint48 listingPrice, uint48 listingTip) = page
                .listings(id);

            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));
            assertEq(0, page.balanceOf(address(page), id));
            assertEq(address(0), seller);
            assertEq(0, listingPrice);
            assertEq(0, listingTip);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchBuy
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchBuyMsgValueInsufficient() external {
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000;
            tips[i] = 1_000;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        uint256 totalSellerProceeds;

        for (uint256 i; i < ids.length; ) {
            (uint256 priceETH, uint256 tipETH) = _calculateTransferValues(
                prices[i],
                tips[i]
            );
            totalSellerProceeds += (priceETH - tipETH);

            unchecked {
                ++i;
            }
        }

        vm.deal(address(this), totalSellerProceeds);
        vm.expectRevert(Page.Insufficient.selector);

        // Send enough ETH to cover seller proceeds but not tips
        page.batchBuy{value: totalSellerProceeds}(ids);
    }

    function testBatchBuy(uint48 price, uint48 tip) external {
        vm.assume(price != 0);
        vm.assume(tip < price);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = price;
            tips[i] = tip;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        uint256 totalPriceETH;
        uint256 totalTipETH;
        uint256 tipRecipientBalanceBefore = TIP_RECIPIENT.balance;
        uint256 sellerBalanceBefore = recipient.balance;

        for (uint256 i; i < ids.length; ) {
            (uint256 priceETH, uint256 tipETH) = _calculateTransferValues(
                prices[i],
                tips[i]
            );
            totalPriceETH += priceETH;
            totalTipETH += tipETH;

            unchecked {
                ++i;
            }
        }

        vm.deal(address(this), totalPriceETH);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchBuy(ids);

        // Send enough ETH to cover seller proceeds but not tips
        page.batchBuy{value: totalPriceETH}(ids);

        assertEq(
            tipRecipientBalanceBefore + totalTipETH,
            TIP_RECIPIENT.balance
        );
        assertEq(
            sellerBalanceBefore + (totalPriceETH - totalTipETH),
            recipient.balance
        );

        for (uint256 i; i < ids.length; ) {
            assertEq(address(this), page.ownerOf(ids[i]));
            assertEq(1, page.balanceOf(address(this), ids[i]));
            assertEq(0, page.balanceOf(address(page), ids[i]));
            assertEq(0, page.balanceOf(recipient, ids[i]));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchBuyPartial(uint48 price, uint48 tip) external {
        vm.assume(price != 0);
        vm.assume(tip < price);

        address recipient = accounts[0];

        // Listing id index - will be canceled before the buy, resulting
        // in only a partial buy
        uint256 cancelIndex = 1;

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = price;
            tips[i] = tip;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        uint256 totalPriceETH;
        uint256 totalTipETH;
        uint256 tipRecipientBalanceBefore = TIP_RECIPIENT.balance;
        uint256 sellerBalanceBefore = recipient.balance;

        for (uint256 i; i < ids.length; ) {
            if (i == cancelIndex) {
                ++i;
                continue;
            }

            (uint256 priceETH, uint256 tipETH) = _calculateTransferValues(
                prices[i],
                tips[i]
            );
            totalPriceETH += priceETH;
            totalTipETH += tipETH;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.cancel(ids[cancelIndex]);

        vm.deal(address(this), totalPriceETH);
        vm.expectEmit(false, false, false, true, address(page));

        emit BatchBuy(ids);

        // Send enough ETH to cover seller proceeds but not tips
        page.batchBuy{value: totalPriceETH}(ids);

        assertEq(
            tipRecipientBalanceBefore + totalTipETH,
            TIP_RECIPIENT.balance
        );
        assertEq(
            sellerBalanceBefore + (totalPriceETH - totalTipETH),
            recipient.balance
        );

        for (uint256 i; i < ids.length; ) {
            if (i == cancelIndex) {
                ++i;
                continue;
            }

            assertEq(address(this), page.ownerOf(ids[i]));
            assertEq(1, page.balanceOf(address(this), ids[i]));
            assertEq(0, page.balanceOf(address(page), ids[i]));
            assertEq(0, page.balanceOf(recipient, ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
