// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DynamicBufferLib} from "solady/utils/DynamicBufferLib.sol";

interface FrontPage {
    struct Listing {
        // Seller address
        address payable seller;
        // Adequate for 79m ether
        uint96 price;
    }

    function nextId() external view returns (uint256);

    function ownerOf(uint256 id) external view returns (address);

    function listings(uint256 id) external view returns (Listing memory);
}

contract FrontPageReader {
    using DynamicBufferLib for DynamicBufferLib.DynamicBuffer;

    FrontPage public immutable frontPage;

    constructor(address _frontPage) {
        frontPage = FrontPage(_frontPage);
    }

    function balanceOf(address owner) external view returns (uint256 balance) {
        uint256 maxId = frontPage.nextId();

        for (uint256 id = 1; id < maxId; ) {
            if (frontPage.ownerOf(id) == owner) ++balance;

            unchecked {
                ++id;
            }
        }
    }

    function ownedIds(
        address owner
    ) external view returns (DynamicBufferLib.DynamicBuffer memory ids) {
        uint256 maxId = frontPage.nextId();

        for (uint256 id = 1; id < maxId; ) {
            if (frontPage.ownerOf(id) == owner) {
                ids.append(abi.encode(id));
            }

            unchecked {
                ++id;
            }
        }
    }

    function allListings()
        external
        view
        returns (DynamicBufferLib.DynamicBuffer memory ids)
    {
        uint256 maxId = frontPage.nextId();

        for (uint256 id = 1; id < maxId; ) {
            unchecked {
                ++id;
            }

            FrontPage.Listing memory listing = frontPage.listings(id);

            if (listing.seller == address(0)) continue;

            ids.append(abi.encode(id, listing.seller, listing.price));
        }
    }

    function listingsByAccount(
        address account
    ) external view returns (DynamicBufferLib.DynamicBuffer memory ids) {
        uint256 maxId = frontPage.nextId();

        for (uint256 id = 1; id < maxId; ) {
            FrontPage.Listing memory listing = frontPage.listings(id);

            if (listing.seller == account)
                ids.append(abi.encode(id, listing.price));

            unchecked {
                ++id;
            }
        }
    }
}