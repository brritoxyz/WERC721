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
    ERC721 internal immutable collection;
    Book internal immutable book;
    Page internal immutable page;

    uint256[] private ownedIds;
    uint256[] private depositedIds;
    uint256 private currentIndex = 0;

    receive() external payable {}

    constructor(ERC721 _collection, Book _book, Page _page) {
        collection = _collection;
        book = _book;
        page = _page;

        // Approve the Page contract to transfer our NFTs
        _collection.setApprovalForAll(address(page), true);
    }

    function getOwnedIds() external view returns (uint256[] memory) {
        return ownedIds;
    }

    function getDepositedIds() external view returns (uint256[] memory) {
        return depositedIds;
    }

    function deposit() public {
        if (ownedIds.length == 0) {
            ICollection(address(collection)).mint(address(this), currentIndex);

            page.deposit(currentIndex, address(this));

            depositedIds.push(currentIndex);

            ++currentIndex;
        } else {
            uint256 id = ownedIds[ownedIds.length - 1];

            page.deposit(id, address(this));

            depositedIds.push(id);
            ownedIds.pop();
        }
    }

    function withdraw() public {
        // If we have no deposited NFTs, deposit one
        if (depositedIds.length == 0) deposit();

        uint256 id = depositedIds[depositedIds.length - 1];

        page.withdraw(id, address(this));

        depositedIds.pop();
        ownedIds.push(id);
    }
}
