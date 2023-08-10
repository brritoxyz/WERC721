// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

contract TestERC721 is ERC721 {
    using LibString for uint256;

    function name() public pure override returns (string memory) {
        return "Test";
    }

    function symbol() public pure override returns (string memory) {
        return "TEST";
    }

    function tokenURI(uint256 id) public pure override returns (string memory) {
        return id.toString();
    }

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }
}
