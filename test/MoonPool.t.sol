// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import {MoonPool} from "src/MoonPool.sol";

contract MoonPoolTest is Test, ERC721TokenReceiver {
    ERC721 private constant AZUKI =
        ERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);
    address private constant AZUKI_OWNER =
        0x2aE6B0630EBb4D155C6e04fCB16840FFA77760AA;

    MoonPool private immutable pool;

    // NFT IDs that are owned by the impersonated/pranked address
    uint256[] private initialNftIds = [0, 2, 7];

    constructor() {
        vm.startPrank(AZUKI_OWNER);

        uint256 iLen = initialNftIds.length;

        // Transfer NFTs from owner to self
        for (uint256 i; i < iLen; ) {
            uint256 id = initialNftIds[i];

            assertTrue(AZUKI.ownerOf(id) == AZUKI_OWNER);

            AZUKI.safeTransferFrom(AZUKI_OWNER, address(this), id);

            assertTrue(AZUKI.ownerOf(id) == address(this));

            unchecked {
                ++i;
            }
        }

        vm.stopPrank();

        pool = new MoonPool(address(this), AZUKI);
    }
}
