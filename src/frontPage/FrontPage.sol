// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clone} from "solady/utils/Clone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {PageERC721} from "src/PageERC721.sol";
import {PageExchange} from "src/PageExchange.sol";
import {IERC721} from "src/interfaces/IERC721.sol";
import {IFrontPageERC721} from "src/interfaces/IFrontPageERC721.sol";

contract FrontPage is Clone, PageERC721, PageExchange {
    using SafeTransferLib for address payable;

    // Fixed clone immutable arg byte offsets
    uint256 private constant IMMUTABLE_ARG_OFFSET_COLLECTION = 0;
    uint256 private constant IMMUTABLE_ARG_OFFSET_CREATOR = 20;
    uint256 private constant IMMUTABLE_ARG_OFFSET_MAX_SUPPLY = 40;
    uint256 private constant IMMUTABLE_ARG_OFFSET_MINT_PRICE = 72;

    bool private _initialized;

    // Next NFT ID to be minted
    uint256 public nextId;

    event Mint();
    event BatchMint();

    error AlreadyInitialized();
    error Zero();
    error Soldout();
    error InvalidMsgValue();

    constructor() payable {
        // Prevent the implementation from being initialized
        _initialized = true;
    }

    /**
     * @notice Initializes the minimal proxy contract storage
     */
    function initialize() external payable {
        if (_initialized) revert AlreadyInitialized();

        // Prevent initialize from being called again
        _initialized = true;

        // Initialize `locked` with the value of 1 (i.e. unlocked)
        locked = 1;

        // Initialize `nextId` to 1 to reduce gas (SSTORE non-zero to non-zero) for the 1st mint onward
        // See the following: https://github.com/wolflo/evm-opcodes/blob/main/gas.md#a7-sstore
        nextId = 1;
    }

    function collection() public pure override returns (address) {
        return _getArgAddress(IMMUTABLE_ARG_OFFSET_COLLECTION);
    }

    function creator() public pure returns (address payable) {
        return payable(_getArgAddress(IMMUTABLE_ARG_OFFSET_CREATOR));
    }

    function maxSupply() public pure returns (uint256) {
        return _getArgUint256(IMMUTABLE_ARG_OFFSET_MAX_SUPPLY);
    }

    function mintPrice() public pure returns (uint256) {
        return _getArgUint256(IMMUTABLE_ARG_OFFSET_MINT_PRICE);
    }

    /**
     * @notice Withdraw mint proceeds to the designated recipient (i.e. creator)
     */
    function withdraw() external payable {
        creator().safeTransferETH(address(this).balance);
    }

    /**
     * @notice Mint the FrontPage token representing the redeemable NFT
     */
    function mint() external payable {
        uint256 _nextId = nextId;

        // Revert if the max NFT supply has already been minted
        if (_nextId > maxSupply()) revert Soldout();

        // Revert if the value sent does not equal the mint price
        if (msg.value != mintPrice()) revert InvalidMsgValue();

        // Set the owner of the token ID to the minter
        ownerOf[_nextId] = msg.sender;

        // Will not overflow since nextId is less than or equal to maxSupply
        unchecked {
            // Increment nextId to the next NFT ID to be minted
            ++nextId;
        }

        emit Mint();
    }

    /**
     * @notice Mint multiple FrontPage tokens representing the redeemable NFTs
     * @param  quantity  uint256  Number of FPTs to mint
     */
    function batchMint(uint256 quantity) external payable {
        // Revert if the value sent does not equal the mint price
        if (msg.value != mintPrice() * quantity) revert InvalidMsgValue();

        unchecked {
            // Update nextId to reflect the additional tokens to be minted
            // Virtually impossible to overflow due to the msg.value check above
            uint256 _nextId = (nextId += quantity);

            // Revert if the max NFT supply has been or will be exceeded post-mint
            if (_nextId > maxSupply()) revert Soldout();

            // If quantity is zero, the loop logic will never be executed
            for (uint256 i = quantity; i > 0; --i) {
                // Set the owner of the token ID to the minter
                ownerOf[_nextId - i] = msg.sender;
            }
        }

        emit BatchMint();
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
        IFrontPageERC721(collection()).mint(msg.sender, id);
    }

    /**
     * @notice Redeem the FrontPage tokens for the underlying NFTs
     * @param  ids  uint256[]  FrontPage token IDs
     */
    function batchRedeem(uint256[] calldata ids) external {
        uint256 id;
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            id = ids[i];

            if (ownerOf[id] != msg.sender) revert Unauthorized();

            // Burn the token to prevent the double-spending
            delete ownerOf[id];

            unchecked {
                ++i;
            }
        }

        // Mint the NFTs for msg.sender with the same IDs as the FrontPage tokens
        IFrontPageERC721(collection()).batchMint(msg.sender, ids);
    }
}
