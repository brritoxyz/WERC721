// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Book} from "src/Book.sol";
import {Page} from "src/Page.sol";

interface ICollection {
    function mint(address, uint256) external;
}

contract PageInvariantHandler is Test, ERC721TokenReceiver {
    enum State {
        Deposited,
        Withdrawn,
        Listed,
        Edited,
        Canceled
    }

    ERC721 internal immutable collection;
    Book internal immutable book;
    Page internal immutable page;
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

    function mintDeposit(uint256 id) public {
        // Cannot mint if the ID is already owned
        if (collection.ownerOf(id) != address(0)) return;

        ICollection(address(collection)).mint(address(this), id);
        page.deposit(id, address(this));

        // Add ID to `ids` array since it is new
        ids.push(id);

        states[id] = State.Deposited;
    }

    function deposit(uint256 index) public {
        // Will underflow on next line if `ids` is empty
        if (ids.length == 0) return;

        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.deposit(id, address(this));

        states[id] = State.Deposited;
    }

    function withdraw(uint256 index) public {
        if (ids.length == 0) return;

        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.withdraw(id, address(this));

        states[id] = State.Withdrawn;
    }

    function list(uint256 index, uint48 price, uint48 tip) public {
        if (ids.length == 0) return;

        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.list(id, price, tip);

        states[id] = State.Listed;
    }

    function edit(uint256 index, uint48 newPrice) public {
        if (ids.length == 0) return;

        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.edit(id, newPrice);

        states[id] = State.Edited;
    }

    function cancel(uint256 index) public {
        if (ids.length == 0) return;

        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.cancel(id);

        states[id] = State.Canceled;
    }
}
