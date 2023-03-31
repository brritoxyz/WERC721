// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract MoonPool is ERC721TokenReceiver, Owned {
    ERC721 public immutable collection;

    error InvalidAddress();

    constructor(address _owner, ERC721 _collection) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
        if (address(_collection) == address(0)) revert InvalidAddress();

        collection = _collection;
    }
}
