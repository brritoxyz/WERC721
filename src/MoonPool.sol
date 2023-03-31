// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract MoonPool is ERC721TokenReceiver, Owned {
    struct Fee {
        address recipient;
        uint96 bps;
    }

    // 10,000 basis points = 100%
    uint96 public constant BPS_BASE = 10_000;

    // Collection royalties can never exceed 10%
    uint80 public constant MAX_COLLECTION_ROYALTIES = 1_000;

    // Protocol fees can never exceed 0.5%
    uint80 public constant MAX_PROTOCOL_FEES = 50;

    ERC721 public immutable collection;

    // Set by the Moonbase team upon outreach from the collection owner
    Fee public collectionRoyalties;

    // Protocol fees are charged upon each exchange and results in...
    // MOON rewards being minted for both the seller and the buyer
    Fee public protocolFees;

    event SetCollectionRoyalties(address indexed recipient, uint96 bps);
    event SetProtocolFees(address indexed recipient, uint96 bps);

    error InvalidAddress();
    error InvalidNumber();

    constructor(address _owner, ERC721 _collection) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
        if (address(_collection) == address(0)) revert InvalidAddress();

        collection = _collection;
    }

    /**
     * @notice Set collection royalties
     * @param recipient  address  Royalties recipient
     * @param bps        uint96   Royalties in basis points (1 = 0.01%)
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
     * @param recipient  address  Protocol fees recipient
     * @param bps        uint96   Protocol fees in basis points (1 = 0.01%)
     */
    function setProtocolFees(address recipient, uint96 bps) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        if (bps > BPS_BASE) revert InvalidNumber();
        if (bps > MAX_PROTOCOL_FEES) revert InvalidNumber();

        protocolFees = Fee(recipient, bps);

        emit SetProtocolFees(recipient, bps);
    }
}
