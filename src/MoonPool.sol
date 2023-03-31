// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

contract MoonPool is ERC721TokenReceiver, Owned, ReentrancyGuard {
    struct Fee {
        // Collection owner-specified address
        address recipient;
        // Denominated in basis points (1 = 0.01%)
        uint96 bps;
    }

    struct Listing {
        // NFT seller, receives ETH upon sale
        address seller;
        // Denominated in ETH
        uint96 price;
    }

    // 10,000 basis points = 100%
    uint96 public constant BPS_BASE = 10_000;

    // Collection royalties can never exceed 10%
    uint80 public constant MAX_COLLECTION_ROYALTIES = 1_000;

    // Protocol fees can never exceed 0.5%
    uint80 public constant MAX_PROTOCOL_FEES = 50;

    // NFT collection contract
    ERC721 public immutable collection;

    // NFT collection listings
    mapping(uint256 id => Listing listing) public collectionListings;

    // Set by the Moonbase team upon outreach from the collection owner
    Fee public collectionRoyalties;

    // Protocol fees are charged upon each exchange and results in...
    // MOON rewards being minted for both the seller and the buyer
    Fee public protocolFees;

    event SetCollectionRoyalties(address indexed recipient, uint96 bps);
    event SetProtocolFees(address indexed recipient, uint96 bps);
    event List(address indexed seller, uint256 indexed id, uint96 price);
    event ListMany(address indexed seller, uint256[] ids, uint96[] prices);

    error InvalidAddress();
    error InvalidNumber();
    error EmptyArray();
    error MismatchedArrays();

    /**
     * @param _owner       address  Contract owner (can set royalties and fees only)
     * @param _collection  ERC721   NFT collection contract
     */
    constructor(address _owner, ERC721 _collection) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
        if (address(_collection) == address(0)) revert InvalidAddress();

        collection = _collection;
    }

    /**
     * @notice Set collection royalties
     * @param  recipient  address  Royalties recipient
     * @param  bps        uint96   Royalties in basis points (1 = 0.01%)
     */
    function setCollectionRoyalties(
        address recipient,
        uint96 bps
    ) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        if (bps > BPS_BASE) revert InvalidNumber();
        if (bps > MAX_COLLECTION_ROYALTIES) revert InvalidNumber();

        collectionRoyalties = Fee(recipient, bps);

        emit SetCollectionRoyalties(recipient, bps);
    }

    /**
     * @notice Set protocol fees
     * @param  recipient  address  Protocol fees recipient
     * @param  bps        uint96   Protocol fees in basis points (1 = 0.01%)
     */
    function setProtocolFees(address recipient, uint96 bps) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        if (bps > BPS_BASE) revert InvalidNumber();
        if (bps > MAX_PROTOCOL_FEES) revert InvalidNumber();

        protocolFees = Fee(recipient, bps);

        emit SetProtocolFees(recipient, bps);
    }

    /*///////////////////////////////////////////////////////////////
                            Seller Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice List a single NFT for sale
     * @param  id     uint256  NFT ID
     * @param  price  uint96   NFT price in ETH
     */
    function list(uint256 id, uint96 price) external nonReentrant {
        if (price == 0) revert InvalidNumber();

        collection.safeTransferFrom(msg.sender, address(this), id);

        collectionListings[id] = Listing(msg.sender, price);

        emit List(msg.sender, id, price);
    }

    /**
     * @notice List many NFTs for sale
     * @param  ids     uint256[]  NFT IDs
     * @param  prices  uint96[]   NFT prices
     */
    function listMany(
        uint256[] calldata ids,
        uint96[] calldata prices
    ) external nonReentrant {
        uint256 iLen = ids.length;

        if (iLen == 0) revert EmptyArray();
        if (iLen != prices.length) revert MismatchedArrays();

        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];

            collection.safeTransferFrom(msg.sender, address(this), id);

            collectionListings[id] = Listing(msg.sender, prices[i]);

            // Will not overflow since it's bound by the `ids` array's length
            unchecked {
                ++i;
            }
        }

        emit ListMany(msg.sender, ids, prices);
    }
}
