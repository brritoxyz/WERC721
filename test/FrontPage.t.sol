// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {FrontPageBook} from "src/frontPage/FrontPageBook.sol";
import {FrontPage} from "src/frontPage/FrontPage.sol";
import {FrontPageERC721} from "src/frontPage/FrontPageERC721.sol";
import {Page} from "src/Page.sol";
import {TestERC721} from "test/lib/TestERC721.sol";

contract FrontPageTests is Test, ERC721TokenReceiver {
    bytes32 internal constant STORAGE_SLOT_INITIALIZED = bytes32(uint256(1));
    bytes32 internal constant STORAGE_SLOT_NEXT_ID = bytes32(uint256(8));
    bytes32 internal constant SALT = keccak256("SALT");
    string internal constant NAME = "Test";
    string internal constant SYMBOL = "TEST";
    uint256 internal constant MAX_SUPPLY = 12_345;
    uint256 internal constant MINT_PRICE = 0.069 ether;

    address payable internal immutable creator = payable(address(this));
    FrontPageBook internal immutable book = new FrontPageBook();
    FrontPageERC721 internal immutable collection;
    FrontPage internal immutable page;

    address[] internal accounts = [address(1), address(2), address(3)];

    event SetCreator(address creator);
    event Mint(address indexed minter, uint256 id);
    event BatchMint(address indexed minter, uint256 quantity);
    event Redeem(address indexed redeemer, uint256 id);
    event BatchRedeem(address indexed redeemer, uint256[] ids);

    receive() external payable {}

    constructor() {
        (uint256 collectionVersion, ) = book.upgradeCollection(
            SALT,
            type(FrontPageERC721).creationCode
        );

        // Call `upgradePage` and set the first page implementation
        (uint256 pageVersion, ) = book.upgradePage(
            SALT,
            type(FrontPage).creationCode
        );

        // Clone the collection and page implementations and assign to variables
        (address collectionAddress, address pageAddress) = book.createPage(
            FrontPageBook.CloneArgs({
                name: NAME,
                symbol: SYMBOL,
                maxSupply: MAX_SUPPLY,
                mintPrice: MINT_PRICE,
                creator: creator
            }),
            collectionVersion,
            pageVersion,
            SALT,
            SALT
        );
        collection = FrontPageERC721(collectionAddress);
        page = FrontPage(pageAddress);
    }

    function _batchMint(
        address to,
        uint256 quantity
    ) internal returns (uint256[] memory ids) {
        uint256 msgValue = MINT_PRICE * quantity;
        uint256 nextId = page.nextId();
        ids = new uint256[](quantity);

        vm.deal(to, msgValue);
        vm.prank(to);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchMint(to, quantity);

        page.batchMint{value: msgValue}(quantity);

        uint256 finalNextId = nextId + quantity;

        for (uint256 i = nextId; i < finalNextId; ) {
            ids[i] = i;

            assertEq(to, page.ownerOf(i));

            unchecked {
                ++i;
            }
        }
    }

    function _setInitialized(bool isInitialized) internal {
        vm.store(
            address(page),
            STORAGE_SLOT_INITIALIZED,
            bytes32(abi.encode(isInitialized))
        );

        assertTrue(
            vm.load(address(page), STORAGE_SLOT_INITIALIZED) ==
                bytes32(abi.encode(isInitialized))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             collection
    //////////////////////////////////////////////////////////////*/

    function testCollection() external {
        assertEq(address(collection), address(page.collection()));
    }

    /*//////////////////////////////////////////////////////////////
                             maxSupply
    //////////////////////////////////////////////////////////////*/

    function testMaxSupply() external {
        assertEq(MAX_SUPPLY, page.maxSupply());
    }

    /*//////////////////////////////////////////////////////////////
                             mintPrice
    //////////////////////////////////////////////////////////////*/

    function testMintPrice() external {
        assertEq(MINT_PRICE, page.mintPrice());
    }

    /*//////////////////////////////////////////////////////////////
                             initializeCreator
    //////////////////////////////////////////////////////////////*/

    function testCannotInitializeCreatorAlreadyInitialized() external {
        bytes32 initializedIsTrue = bytes32(abi.encode(true));

        // When FrontPages are cloned, they are also initialized - this must be true
        assertTrue(
            vm.load(address(page), STORAGE_SLOT_INITIALIZED) ==
                initializedIsTrue
        );

        vm.expectRevert(Page.AlreadyInitialized.selector);

        page.initializeCreator(creator);
    }

    function testCannotInitializeCreatorInvalidAddress() external {
        // Set `_initialized` to false to test param validation
        _setInitialized(false);

        vm.expectRevert(FrontPage.InvalidAddress.selector);

        page.initializeCreator(payable(address(0)));
    }

    function testInitializeCreator() external {
        // Set `_initialized` to false to test setting `creator`
        _setInitialized(false);

        address payable newCreator = payable(accounts[0]);

        assertTrue(newCreator != page.creator());

        vm.expectEmit(false, false, false, true, address(page));

        emit SetCreator(newCreator);

        page.initializeCreator(newCreator);
    }

    /*//////////////////////////////////////////////////////////////
                             setCreator
    //////////////////////////////////////////////////////////////*/

    function testCannotSetCreatorNotCreator() external {
        address unauthorizedMsgSender = accounts[0];
        address payable newCreator = payable(accounts[0]);

        assertTrue(unauthorizedMsgSender != page.creator());

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(FrontPage.NotCreator.selector);

        page.setCreator(newCreator);
    }

    function testCannotSetCreatorInvalidAddress() external {
        address msgSender = creator;
        address payable newCreator = payable(address(0));

        assertEq(msgSender, page.creator());

        vm.prank(msgSender);
        vm.expectRevert(FrontPage.InvalidAddress.selector);

        page.setCreator(newCreator);
    }

    function testSetCreator() external {
        address msgSender = creator;
        address payable newCreator = payable(accounts[0]);

        assertEq(msgSender, page.creator());
        assertTrue(newCreator != msgSender);

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(page));

        emit SetCreator(newCreator);

        page.setCreator(newCreator);

        assertEq(newCreator, page.creator());
    }

    /*//////////////////////////////////////////////////////////////
                             withdrawProceeds
    //////////////////////////////////////////////////////////////*/

    function testCannotWithdrawProceedsNotCreator() external {
        address unauthorizedMsgSender = accounts[0];

        assertTrue(unauthorizedMsgSender != page.creator());

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(FrontPage.NotCreator.selector);

        page.withdrawProceeds();
    }

    function testWithdrawProceeds() external {
        address msgSender = creator;
        uint256 offer = 1 ether;

        assertEq(msgSender, page.creator());

        vm.deal(msgSender, MINT_PRICE + offer);
        vm.prank(msgSender);

        // Mint to add ETH to the FrontPage that will be withdrawn
        page.mint{value: MINT_PRICE}();

        // Make an offer to add ETH to the FrontPage that should NOT be withdrawn
        page.makeOffer{value: offer}(offer, 1);

        // Verify that the FrontPage has
        assertEq(MINT_PRICE + offer, address(page).balance);

        uint256 mintProceeds = page.mintProceeds();
        uint256 pageBalanceBefore = address(page).balance;
        uint256 creatorBalanceBefore = address(msgSender).balance;

        vm.prank(msgSender);

        page.withdrawProceeds();

        assertEq(pageBalanceBefore - mintProceeds, address(page).balance);
        assertEq(offer, address(page).balance);
        assertEq(
            creatorBalanceBefore + mintProceeds,
            address(msgSender).balance
        );
    }

    /*//////////////////////////////////////////////////////////////
                             mint
    //////////////////////////////////////////////////////////////*/

    function testCannotMintSoldout() external {
        address msgSender = address(this);

        vm.store(address(page), STORAGE_SLOT_NEXT_ID, bytes32(MAX_SUPPLY + 1));

        assertGt(page.nextId(), page.maxSupply());

        vm.prank(msgSender);
        vm.expectRevert(FrontPage.Soldout.selector);

        page.mint();
    }

    function testCannotMintInvalidMsgValue(uint96 msgValue) external {
        address msgSender = address(this);

        vm.assume(msgValue != MINT_PRICE);
        vm.deal(msgSender, msgValue);
        vm.prank(msgSender);
        vm.expectRevert(FrontPage.InvalidMsgValue.selector);

        page.mint{value: msgValue}();
    }

    function testMint(address msgSender) external {
        vm.assume(msgSender != address(0));

        assertLe(page.nextId(), page.maxSupply());

        uint256 id = page.nextId();
        uint256 pageBalanceBefore = address(page).balance;

        assertEq(address(0), page.ownerOf(id));

        uint256 value = MINT_PRICE;

        vm.deal(msgSender, value);
        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(page));

        emit Mint(msgSender, id);

        page.mint{value: value}();

        assertEq(msgSender, page.ownerOf(id));
        assertEq(pageBalanceBefore + value, address(page).balance);
        assertEq(id + 1, page.nextId());
    }

    /*//////////////////////////////////////////////////////////////
                             batchMint
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchMintInvalidMsgValue(uint256 quantity) external {
        vm.assume(quantity != 0);
        vm.assume(quantity <= MAX_SUPPLY);

        address msgSender = address(this);
        uint256 value = (quantity * MINT_PRICE) - 1;

        vm.prank(msgSender);
        vm.expectRevert(FrontPage.InvalidMsgValue.selector);

        page.batchMint{value: value}(quantity);
    }

    function testCannotBatchMintSoldout(uint48 quantity) external {
        vm.assume(quantity != 0);
        vm.store(address(page), STORAGE_SLOT_NEXT_ID, bytes32(MAX_SUPPLY));

        address msgSender = address(this);
        uint256 value = uint256(quantity) * MINT_PRICE;

        vm.deal(msgSender, value);
        vm.expectRevert(FrontPage.Soldout.selector);

        page.batchMint{value: value}(quantity);
    }

    function testBatchMint() external {
        address msgSender = address(this);
        uint256 quantity = 5;
        uint256 startingId = page.nextId();

        for (uint256 i = 0; i < quantity; ) {
            assertEq(address(0), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }

        assertLe(page.nextId() + quantity, page.maxSupply());

        uint256 value = quantity * MINT_PRICE;

        vm.deal(msgSender, value);
        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchMint(msgSender, quantity);

        page.batchMint{value: value}(quantity);

        for (uint256 i = 0; i < quantity; ) {
            assertEq(msgSender, page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }
    }

    function testBatchMintFuzz(uint8 quantity) external {
        address msgSender = address(this);
        uint256 startingId = page.nextId();

        for (uint256 i = 0; i < quantity; ) {
            assertEq(address(0), page.ownerOf(startingId + i));

            unchecked {
                ++i;
            }
        }

        assertLe(page.nextId() + quantity, page.maxSupply());

        uint256 value = quantity * MINT_PRICE;

        vm.deal(msgSender, value);
        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchMint(msgSender, quantity);

        page.batchMint{value: value}(quantity);

        uint256 endingId = startingId + quantity;

        for (uint256 i = startingId; i < endingId; ) {
            assertEq(msgSender, page.ownerOf(i));

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             redeem
    //////////////////////////////////////////////////////////////*/

    function testCannotRedeemNotOwner() external {
        address msgSender = address(this);
        uint256 id = page.nextId();

        assertEq(address(0), page.ownerOf(id));

        vm.prank(msgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.redeem(id);
    }

    function testRedeem() external {
        address msgSender = address(this);
        uint256 id = page.nextId();

        assertEq(address(0), page.ownerOf(id));

        page.mint{value: MINT_PRICE}();

        assertEq(msgSender, page.ownerOf(id));

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);

        collection.ownerOf(id);

        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(page));

        emit Redeem(msgSender, id);

        page.redeem(id);

        assertEq(address(0), page.ownerOf(id));
        assertEq(msgSender, collection.ownerOf(id));
    }

    /*//////////////////////////////////////////////////////////////
                             batchRedeem
    //////////////////////////////////////////////////////////////*/

    function testCannotBatchRedeemNotOwner() external {
        address owner = address(this);
        uint256 mintQuantity = 5;
        address unauthorizedMsgSender = accounts[0];
        uint256[] memory ids = _batchMint(owner, mintQuantity);

        for (uint256 i = 0; i < ids.length; ) {
            assertTrue(unauthorizedMsgSender != page.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }

        vm.prank(unauthorizedMsgSender);
        vm.expectRevert(Page.NotOwner.selector);

        page.batchRedeem(ids);
    }

    function testBatchRedeem() external {
        address msgSender = address(this);
        uint256 mintQuantity = 5;
        uint256[] memory ids = _batchMint(msgSender, mintQuantity);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(msgSender, page.ownerOf(ids[i]));

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);

            collection.ownerOf(ids[i]);

            unchecked {
                ++i;
            }
        }

        vm.prank(msgSender);
        vm.expectEmit(true, false, false, true, address(page));

        emit BatchRedeem(msgSender, ids);

        page.batchRedeem(ids);

        for (uint256 i = 0; i < ids.length; ) {
            assertEq(address(0), page.ownerOf(ids[i]));
            assertEq(msgSender, collection.ownerOf(ids[i]));

            unchecked {
                ++i;
            }
        }
    }
}
