// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DynamicBufferLib} from "solady/utils/DynamicBufferLib.sol";
import {FrontPage} from "src/frontPage/FrontPage.sol";

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
            if (frontPage.ownerOf(id) == owner) ids = ids.append(abi.encode(id));

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

            (address seller, uint96 price) = frontPage.listings(id);

            if (seller == address(0)) continue;

            ids = ids.append(abi.encode(id, seller, price));
        }
    }

    function listingsByAccount(
        address account
    ) external view returns (DynamicBufferLib.DynamicBuffer memory ids) {
        uint256 maxId = frontPage.nextId();

        for (uint256 id = 1; id < maxId; ) {
            (address seller, uint96 price) = frontPage.listings(id);

            if (seller == account) ids = ids.append(abi.encode(id, price));

            unchecked {
                ++id;
            }
        }
    }
}
