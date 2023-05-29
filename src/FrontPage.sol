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

    // Total NFT supply and the next NFT ID to be minted (IDs begin at 0)
    uint256 public totalSupply;

    error Zero();
    error Soldout();
    error InsufficientFunds();
    error Unauthorized();

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

    /**
     * @notice Mint the FrontPage token representing the redeemable NFT
     */
    function mint() external payable {
        // Revert if the max NFT supply has already been minted
        if (totalSupply == uint256(maxSupply)) revert Soldout();

        // Revert if the value sent is less than the mint price
        if (msg.value != uint256(mintPrice)) revert InsufficientFunds();

        // Set the owner of the token ID to the minter
        ownerOf[totalSupply] = msg.sender;

        // Increment totalSupply and the next NFT ID to be minted
        ++totalSupply;
    }

    /**
     * @notice Mint the FrontPage token representing the redeemable NFT
     */
    function redeem(uint256 id) external {
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Transfer the FrontPage token to self, effectively burning it
        // without affecting the total supply
        ownerOf[id] = address(this);

        // Mint the NFT for msg.sender with the same ID as the FrontPage token
        collection.mint(msg.sender, id);
    }
}
