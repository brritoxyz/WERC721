// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721} from "src/interfaces/IERC721.sol";

abstract contract PageERC721 {
    function collection() public pure virtual returns (address);

    function name() external view returns (string memory) {
        return IERC721(collection()).name();
    }

    function symbol() external view returns (string memory) {
        return IERC721(collection()).symbol();
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        return IERC721(collection()).tokenURI(_tokenId);
    }
}
