// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {FrontPageERC721} from "src/FrontPageERC721.sol";
import {PageToken} from "src/PageToken.sol";

contract FrontPage is PageToken {
    using SafeTransferLib for address payable;

    // NFT collection deployed by this contract
    FrontPageERC721 public immutable collection;

    // NFT creator, has permission to update the NFT collection and receive funds
    address payable public immutable creator;

    // Maximum NFT supply
    uint256 public immutable maxSupply;

    // NFT mint price
    uint256 public immutable mintPrice;

    // Next NFT ID to be minted
    uint256 public nextId = 1;

    error Zero();
    error Soldout();
    error InvalidMsgValue();
    error Unauthorized();

    constructor(
        string memory _name,
        string memory _symbol,
        address payable _creator,
        uint256 _maxSupply,
        uint256 _mintPrice
    ) {
        if (_creator == address(0)) revert Zero();
        if (_maxSupply == 0) revert Zero();

        // Deploy the associated NFT collection
        collection = new FrontPageERC721(_name, _symbol, _creator, _maxSupply);

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
     * @notice Withdraw mint proceeds to the designated recipient (i.e. creator)
     */
    function withdraw() external {
        creator.safeTransferETH(address(this).balance);
    }

    /**
     * @notice Mint the FrontPage token representing the redeemable NFT
     */
    function mint() external payable {
        uint256 _nextId = nextId;

        // Revert if the max NFT supply has already been minted
        if (_nextId > maxSupply) revert Soldout();

        // Revert if the value sent does not equal the mint price
        if (msg.value != mintPrice) revert InvalidMsgValue();

        // Set the owner of the token ID to the minter
        ownerOf[_nextId] = msg.sender;

        // Will not overflow since nextId is less than or equal to maxSupply
        unchecked {
            // Increment nextId to the next NFT ID to be minted
            ++nextId;
        }
    }

    /**
     * @notice Mint multiple FrontPage tokens representing the redeemable NFTs
     * @param  quantity  uint256  Number of FPTs to mint
     */
    function batchMint(uint256 quantity) external payable {
        // Revert if the value sent does not equal the mint price
        if (msg.value != mintPrice * quantity) revert InvalidMsgValue();

        unchecked {
            // Update nextId to reflect the additional tokens to be minted
            // Virtually impossible to overflow due to the msg.value check above
            uint256 _nextId = (nextId += quantity);

            // Revert if the max NFT supply has been or will be exceeded post-mint
            if (_nextId > maxSupply) revert Soldout();

            // If quantity is zero, the loop logic will never be executed
            for (uint256 i = quantity; i > 0; --i) {
                // Set the owner of the token ID to the minter
                ownerOf[_nextId - i] = msg.sender;
            }
        }
    }

    /**
     * @notice Redeem the FrontPage token for the underlying NFT
     * @param  id  uint256  FrontPage token ID
     */
    function redeem(uint256 id) external {
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Burn the token to prevent the double-spending
        delete ownerOf[id];

        // Mint the NFT for msg.sender with the same ID as the FrontPage token
        collection.mint(msg.sender, id);
    }

    /**
     * @notice Redeem the FrontPage tokens for the underlying NFTs
     * @param  ids  uint256[]  FrontPage token IDs
     */
    function batchRedeem(uint256[] calldata ids) external {
        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            if (ownerOf[id] != msg.sender) revert Unauthorized();

            // Burn the token to prevent the double-spending
            delete ownerOf[id];

            unchecked {
                ++i;
            }
        }

        // Mint the NFTs for msg.sender with the same IDs as the FrontPage tokens
        collection.batchMint(msg.sender, ids);
    }
}
