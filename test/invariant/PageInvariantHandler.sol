// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Book} from "src/Book.sol";
import {Page} from "src/Page.sol";

interface ICollection {
    function mint(address, uint256) external;
}

contract PageInvariantHandler is
    CommonBase,
    StdCheats,
    StdUtils,
    ERC721TokenReceiver
{
    enum TokenState {
        Deposited,
        Withdrawn,
        Listed,
        Edited,
        Canceled
    }

    struct State {
        address recipient;
        TokenState state;
    }

    ERC721 internal immutable collection;
    Book internal immutable book;
    Page internal immutable page;
    uint256 internal currentIndex;
    uint256[] internal ids;

    mapping(uint256 id => State) public states;

    receive() external payable {}

    constructor(ERC721 _collection, Book _book, Page _page) {
        collection = _collection;
        book = _book;
        page = _page;

        // Approve the Page contract to transfer our NFTs
        _collection.setApprovalForAll(address(page), true);
    }

    function getIds() external view returns (uint256[] memory) {
        return ids;
    }

    function mintDeposit() public {
        ICollection(address(collection)).mint(msg.sender, currentIndex);

        vm.startPrank(msg.sender);

        collection.setApprovalForAll(address(page), true);

        page.deposit(currentIndex, msg.sender);

        vm.stopPrank();

        // Add ID to `ids` array since it is new
        ids.push(currentIndex);

        states[currentIndex] = State(msg.sender, TokenState.Deposited);

        ++currentIndex;
    }

    function deposit() public {
        // Will underflow on next line if `ids` is empty
        if (ids.length == 0) return;

        uint256 id = ids[ids.length - 1];

        if (states[id].state != TokenState.Withdrawn) return;

        vm.prank(states[id].recipient);

        page.deposit(id, states[id].recipient);

        states[id] = State(states[id].recipient, TokenState.Deposited);
    }

    function withdraw() public {
        if (ids.length == 0) return;

        uint256 id = ids[ids.length - 1];

        if (states[id].state != TokenState.Deposited) return;

        vm.prank(states[id].recipient);

        page.withdraw(id, states[id].recipient);

        states[id] = State(states[id].recipient, TokenState.Withdrawn);
    }

    function list(uint48 price, uint48 tip) public {
        price = uint48(bound(price, 1, type(uint48).max));
        tip = uint48(bound(tip, 0, price));

        if (ids.length == 0) return;

        uint256 id = ids[ids.length - 1];

        if (states[id].state != TokenState.Deposited) return;

        vm.prank(states[id].recipient);

        page.list(id, price, tip);

        states[id] = State(states[id].recipient, TokenState.Listed);
    }

    function edit(uint48 newPrice) public {
        newPrice = uint48(bound(newPrice, 1, type(uint48).max));

        if (ids.length == 0) return;

        uint256 id = ids[ids.length - 1];

        if (states[id].state != TokenState.Listed) return;

        (, , uint48 tip) = page.listings(id);

        if (newPrice < tip) newPrice = tip;

        vm.prank(states[id].recipient);

        page.edit(id, newPrice);

        states[id] = State(states[id].recipient, TokenState.Edited);
    }

    function cancel() public {
        if (ids.length == 0) return;

        uint256 id = ids[ids.length - 1];

        if (states[id].state != TokenState.Listed) return;

        vm.prank(states[id].recipient);

        page.cancel(id);

        states[id] = State(states[id].recipient, TokenState.Canceled);
    }
}
