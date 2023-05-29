// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FrontPageERC721} from "src/FrontPageERC721.sol";
import {PageToken} from "src/PageToken.sol";

contract FrontPage is PageToken {
    // NFT collection deployed by this contract
    FrontPageERC721 public immutable collection;

    // NFT creator, has permission to update the NFT collection and receive funds
    address payable public immutable creator;

    // Maximum NFT supply
    uint16 public immutable maxSupply;

    // NFT mint price
    uint240 public immutable mintPrice;

    error Zero();

    constructor(
        string memory _name,
        string memory _symbol,
        address payable _creator,
        uint16 _maxSupply,
        uint240 _mintPrice
    ) {
        if (_creator == address(0)) revert Zero();
        if (_maxSupply == 0) revert Zero();

        // Deploy the associated NFT collection
        collection = new FrontPageERC721(_name, _symbol, _creator);

        creator = _creator;
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
    }

    function name() external view override returns (string memory) {
        return collection.name();
    }

    function symbol() external view override returns (string memory) {
        return collection.symbol();
    }

    function tokenURI(
        uint256 _tokenId
    ) external view override returns (string memory) {
        return collection.tokenURI(_tokenId);
    }
}
