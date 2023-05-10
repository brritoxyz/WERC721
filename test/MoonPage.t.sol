// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {MoonBook} from "src/MoonBook.sol";
import {MoonPage} from "src/MoonPage.sol";

contract MoonPageTest is Test, ERC721TokenReceiver {
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);
    uint256 private constant ONE = 1;
    address payable private constant TIP_RECIPIENT =
        payable(0x9c9dC2110240391d4BEe41203bDFbD19c279B429);

    MoonBook private immutable book;
    MoonPage private immutable page;
    uint256 private immutable valueDenom;

    uint256[] private ids = [1, 39, 111];
    address[] private accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

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
    event URI(string value, uint256 indexed id);
    event Initialize(address owner, ERC721 collection);
    event SetTipRecipient(address tipRecipient);
    event List(uint256 indexed id, address indexed seller);
    event Edit(uint256 indexed id, address indexed seller);
    event Cancel(uint256 indexed id, address indexed seller);
    event Buy(uint256 indexed id, address indexed buyer);
    event BatchList(address indexed seller, uint256[] ids);
    event BatchEdit(address indexed seller, uint256[] ids);
    event BatchCancel(address indexed seller, uint256[] ids);
    event BatchBuy(address indexed buyer, uint256[] ids);

    constructor() {
        book = new MoonBook();
        page = MoonPage(book.createPage(LLAMA));
        valueDenom = page.VALUE_DENOM();

        // Verify that page cannot be initialized again
        vm.expectRevert("Initializable: contract is already initialized");

        page.initialize(address(this), LLAMA);
        page.setTipRecipient(TIP_RECIPIENT);
    }

    function setUp() external {
        for (uint256 i; i < ids.length; ) {
            address originalOwner = LLAMA.ownerOf(ids[i]);

            vm.prank(originalOwner);

            LLAMA.safeTransferFrom(originalOwner, address(this), ids[i]);

            unchecked {
                ++i;
            }
        }

        LLAMA.setApprovalForAll(address(page), true);
    }

    function _calculateTransferValues(
        uint256 price,
        uint256 tip
    ) private view returns (uint256 priceETH, uint256 tipETH) {
        return (price * valueDenom, tip * valueDenom);
    }

    /*//////////////////////////////////////////////////////////////
                             setURI
    //////////////////////////////////////////////////////////////*/

    function testCannotSetURIUnauthorized() external {
        address caller = accounts[0];

        assertTrue(caller != page.owner());

        vm.prank(caller);
        vm.expectRevert("UNAUTHORIZED");

        page.setURI("");
    }

    function testSetURI() external {
        address caller = address(this);
        string memory newuri = "hello";

        assertEq(caller, page.owner());

        // Compare uri string hashes
        assertTrue(
            keccak256(abi.encodePacked(newuri)) !=
                keccak256(abi.encodePacked(page.uri(0)))
        );

        vm.expectEmit(false, true, false, true, address(page));

        emit URI(newuri, 0);

        page.setURI(newuri);

        assertEq(
            keccak256(abi.encodePacked(newuri)),
            keccak256(abi.encodePacked(page.uri(0)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             setTipRecipient
    //////////////////////////////////////////////////////////////*/

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

    function testCannotDepositRecipientZero() external {
        address recipient = address(0);

        vm.expectRevert("UNSAFE_RECIPIENT");

        page.deposit(ids[0], recipient);
    }

    function testDeposit() external {
        uint256 id;
        address recipient;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            recipient = accounts[i];

            assertEq(address(this), LLAMA.ownerOf(id));
            assertEq(address(0), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.expectEmit(true, true, true, true, address(page));

            emit TransferSingle(address(this), address(0), recipient, id, 1);

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

    function testCannotBatchDepositIdsZero() external {
        uint256[] memory depositIds = new uint256[](0);
        address recipient = accounts[0];

        vm.expectRevert(MoonPage.Zero.selector);

        page.batchDeposit(depositIds, recipient);
    }

    function testCannotBatchDepositRecipientZero() external {
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = ids[0];
        address recipient = address(0);

        vm.expectRevert("UNSAFE_RECIPIENT");

        page.batchDeposit(depositIds, recipient);
    }

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

        vm.expectEmit(true, true, true, true, address(page));

        emit TransferBatch(address(this), address(0), recipient, ids, amounts);

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
        vm.expectRevert(MoonPage.Unauthorized.selector);

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
            vm.expectEmit(true, true, true, true, address(page));

            emit TransferSingle(owner, owner, address(0), id, 1);

            page.withdraw(id, recipient);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             batchWithdraw
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchWithdrawIdsZero() external {
        uint256[] memory withdrawIds = new uint256[](0);
        address recipient = accounts[0];

        vm.expectRevert(MoonPage.Zero.selector);

        page.batchWithdraw(withdrawIds, recipient);
    }

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
        vm.expectRevert(MoonPage.Unauthorized.selector);

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
        vm.expectEmit(true, true, true, true, address(page));

        emit TransferBatch(recipient, recipient, address(0), ids, amounts);

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

        vm.expectRevert(MoonPage.Unauthorized.selector);

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
        vm.expectRevert(MoonPage.Invalid.selector);

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
        vm.expectRevert(MoonPage.Zero.selector);

        page.list(id, price, tip);
    }

    function testList(uint16 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint48 price = 100_000 * uint48(priceMultiplier);
            uint48 tip = 1_000 * uint48(priceMultiplier);

            page.deposit(id, recipient);

            assertEq(recipient, page.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));
            assertEq(0, page.balanceOf(address(page), id));

            vm.prank(recipient);
            vm.expectEmit(true, true, false, true, address(page));

            emit List(id, recipient);

            page.list(id, price, tip);

            (address seller, uint48 listingPrice, uint48 listingTip) = page
                .listings(id);

            assertEq(address(page), page.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(recipient, seller);
            assertEq(price, listingPrice);
            assertEq(tip, listingTip);

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

        vm.expectRevert(MoonPage.Zero.selector);

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

        vm.expectRevert(MoonPage.Unauthorized.selector);

        page.edit(id, newPrice);
    }

    function testEdit(uint16 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint48 price = 100_000 * uint48(priceMultiplier);
            uint48 tip = 1_000 * uint48(priceMultiplier);
            uint48 newPrice = 200 * uint48(priceMultiplier);

            assertTrue(price != newPrice);

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price, tip);

            (address seller, uint48 listingPrice, uint48 listingTip) = page
                .listings(id);

            assertEq(recipient, seller);
            assertEq(price, listingPrice);

            vm.prank(recipient);
            vm.expectEmit(true, true, false, true, address(page));

            emit Edit(id, recipient);

            page.edit(id, newPrice);

            (seller, listingPrice, listingTip) = page.listings(id);

            // Verify that the updated listing has the same seller, different price
            assertEq(recipient, seller);
            assertEq(newPrice, listingPrice);

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

        vm.expectRevert(MoonPage.Unauthorized.selector);

        page.cancel(id);
    }

    function testCancel(uint16 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        for (uint256 i; i < ids.length; ) {
            uint256 id = ids[i];
            address recipient = accounts[i];
            uint48 price = 100_000 * uint48(priceMultiplier);
            uint48 tip = 1_000 * uint48(priceMultiplier);

            page.deposit(id, recipient);

            vm.prank(recipient);

            page.list(id, price, tip);

            assertEq(address(page), page.ownerOf(id));
            assertEq(1, page.balanceOf(address(page), id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.prank(recipient);
            vm.expectEmit(true, true, false, true, address(page));

            emit Cancel(id, recipient);

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

    function testCannotBuyMsgValueZero() external {
        uint256 id = ids[0];
        uint256 msgValue = 0;

        vm.expectRevert(MoonPage.Zero.selector);

        page.buy{value: msgValue}(id);
    }

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

            vm.expectRevert(MoonPage.Insufficient.selector);
        } else {
            vm.expectRevert(MoonPage.Nonexistent.selector);
        }

        // Attempt to buy with msg.value less than price
        page.buy{value: price - 1}(id);
    }

    function testBuy(uint48 price, uint48 tip) external {
        vm.assume(price != 0);
        vm.assume(price < 1_000_000);
        vm.assume(price > tip);
        vm.assume(tip < 1_000);

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

            vm.expectEmit(true, false, false, true, address(page));

            emit Buy(id, recipient);

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

    function testCannotBatchListEmptyIdsArrayInvalid() external {
        uint256[] memory listIds = new uint256[](0);
        uint48[] memory prices = new uint48[](0);
        uint48[] memory tips = new uint48[](0);

        vm.expectRevert(MoonPage.Invalid.selector);

        page.batchList(listIds, prices, tips);
    }

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

    function testBatchList(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000 * uint48(priceMultiplier);
            tips[i] = 1_000 * uint48(priceMultiplier);

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchList(recipient, ids);

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

    function testCannotBatchEditEmptyIdsArrayInvalid() external {
        uint256[] memory editIds = new uint256[](0);
        uint48[] memory newPrices = new uint48[](0);

        vm.expectRevert(MoonPage.Invalid.selector);

        page.batchEdit(editIds, newPrices);
    }

    function testCannotBatchEditMismatchedArrayInvalid() external {
        uint48[] memory newPrices = new uint48[](0);

        vm.expectRevert(stdError.indexOOBError);

        page.batchEdit(ids, newPrices);
    }

    function testCannotBatchEditNewPriceZero() external {
        uint48[] memory newPrices = new uint48[](ids.length);

        vm.expectRevert(MoonPage.Zero.selector);

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

        vm.expectRevert(MoonPage.Unauthorized.selector);

        page.batchEdit(ids, newPrices);
    }

    function testBatchEdit(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);
        uint48[] memory newPrices = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000 * uint48(priceMultiplier);
            tips[i] = 1_000 * uint48(priceMultiplier);
            newPrices[i] = 200_000 * uint48(priceMultiplier);

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        vm.prank(recipient);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchEdit(recipient, ids);

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

    function testCannotBatchCancelEmptyIdsArrayInvalid() external {
        uint256[] memory cancelIds = new uint256[](0);

        vm.expectRevert(MoonPage.Invalid.selector);

        page.batchCancel(cancelIds);
    }

    function testCannotBatchCancelUnauthorized() external {
        uint48 priceMultiplier = 10;
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000 * priceMultiplier;
            tips[i] = 1_000 * priceMultiplier;

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        vm.expectRevert(MoonPage.Unauthorized.selector);

        page.batchCancel(ids);
    }

    function testBatchCancel(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000 * uint48(priceMultiplier);
            tips[i] = 1_000 * uint48(priceMultiplier);

            unchecked {
                ++i;
            }
        }

        vm.prank(recipient);

        page.batchList(ids, prices, tips);

        vm.prank(recipient);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchCancel(recipient, ids);

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

    function testCannotBatchBuyEmptyIdsArrayInvalid() external {
        uint256[] memory buyIds = new uint256[](0);

        vm.expectRevert(MoonPage.Invalid.selector);

        page.batchBuy(buyIds);
    }

    function testCannotBatchBuyMsgValueZero() external {
        vm.expectRevert(MoonPage.Zero.selector);

        page.batchBuy(ids);
    }

    function testCannotBatchBuyMsgValueInsufficient() external {
        uint48 priceMultiplier = 10;
        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000 * priceMultiplier;
            tips[i] = 1_000 * priceMultiplier;

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
        vm.expectRevert(MoonPage.Insufficient.selector);

        // Send enough ETH to cover seller proceeds but not tips
        page.batchBuy{value: totalSellerProceeds}(ids);
    }

    function testBatchBuy(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        address recipient = accounts[0];

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000 * uint48(priceMultiplier);
            tips[i] = 1_000 * uint48(priceMultiplier);

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
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchBuy(address(this), ids);

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

    function testBatchBuyPartial(uint8 priceMultiplier) external {
        vm.assume(priceMultiplier != 0);

        address recipient = accounts[0];

        // Listing id index - will be canceled before the buy, resulting
        // in only a partial buy
        uint256 cancelIndex = 1;

        page.batchDeposit(ids, recipient);

        uint48[] memory prices = new uint48[](ids.length);
        uint48[] memory tips = new uint48[](ids.length);

        for (uint256 i; i < ids.length; ) {
            prices[i] = 100_000 * uint48(priceMultiplier);
            tips[i] = 1_000 * uint48(priceMultiplier);

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
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchBuy(address(this), ids);

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
