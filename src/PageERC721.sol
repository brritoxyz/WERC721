// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solady/tokens/ERC721.sol";

abstract contract PageERC721 {
    function collection() public pure virtual returns (address);

    function name() external view returns (string memory) {
        return ERC721(collection()).name();
    }

    function symbol() external view returns (string memory) {
        return ERC721(collection()).symbol();
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        return ERC721(collection()).tokenURI(_tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
