// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {MoonBookV2} from "src/MoonBookV2.sol";
import {MoonPage} from "src/MoonPage.sol";

contract MoonPageTest is Test, ERC721TokenReceiver {
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    MoonBookV2 private immutable book;
    MoonPage private immutable page;

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

    constructor() {
        book = new MoonBookV2();
        page = MoonPage(book.createPage(LLAMA));
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

    function testCannotDepositRecipientZero() external {
        address recipient = address(0);

        vm.expectRevert(MoonPage.Zero.selector);

        page.deposit(ids[0], recipient);
    }

    function testDeposit() external {
        uint256 id;
        address recipient;
        uint256 iLen = ids.length;

        for (uint256 i; i < iLen; ) {
            id = ids[i];
            recipient = accounts[i];

            assertEq(address(this), LLAMA.ownerOf(id));
            assertEq(0, page.balanceOf(recipient, id));

            vm.expectEmit(true, true, true, true, address(page));

            emit TransferSingle(address(this), address(0), recipient, id, 1);

            page.deposit(id, recipient);

            assertEq(address(page), LLAMA.ownerOf(id));
            assertEq(1, page.balanceOf(recipient, id));

            unchecked {
                ++i;
            }
        }
    }

    function testCannotWithdrawRecipientZero() external {
        address recipient = address(0);

        vm.expectRevert(MoonPage.Zero.selector);

        page.withdraw(ids[0], recipient);
    }

    function testCannotWithdrawMsgSenderInvalid() external {
        address msgSender = accounts[0];
        uint256 id = ids[0];
        address recipient = accounts[0];

        vm.prank(msgSender);
        vm.expectRevert(MoonPage.Invalid.selector);

        page.withdraw(id, recipient);
    }

    function testWithdraw() external {
        uint256 id;
        address recipient;
        uint256 iLen = ids.length;

        // Deposit the NFTs and mint derivative tokens for recipients
        for (uint256 i; i < iLen; ) {
            id = ids[i];
            recipient = accounts[i];

            page.deposit(id, recipient);

            unchecked {
                ++i;
            }
        }

        address owner;

        // Withdraw the NFTs by redeeming the derivative tokens as their owners
        for (uint256 i; i < iLen; ) {
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
}
