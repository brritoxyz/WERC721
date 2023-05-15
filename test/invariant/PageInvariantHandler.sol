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
        Owned,
        Deposited,
        Listed,
        ListedWithTip,
        Edited,
        EditedWithTip,
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
        ICollection(address(collection)).mint(address(this), id);
        page.deposit(id, address(this));

        // Add ID to `ids` array since it is new
        ids.push(id);

        states[id] = State.Deposited;
    }

    function deposit(uint256 index) public {
        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.deposit(id, address(this));

        states[id] = State.Deposited;
    }

    function withdraw(uint256 index) public {
        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.withdraw(id, address(this));

        states[id] = State.Owned;
    }

    function list(uint256 index, uint48 price) public {
        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.list(id, price, 0);

        states[id] = State.Listed;
    }

    function list(uint256 index, uint48 price, uint48 tip) public {
        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.list(id, price, tip);

        states[id] = State.ListedWithTip;
    }

    function edit(uint256 index, uint48 newPrice) public {
        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.edit(id, newPrice);

        if (states[id] == State.Listed) {
            states[id] = State.Edited;
        } else {
            states[id] = State.EditedWithTip;
        }
    }

    function cancel(uint256 index) public {
        index = bound(index, 0, ids.length - 1);
        uint256 id = ids[index];

        page.cancel(id);

        states[id] = State.Canceled;
    }
}
