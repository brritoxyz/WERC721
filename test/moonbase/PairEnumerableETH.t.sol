// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {LinearBase} from "test/moonbase/LinearBase.sol";
import {Pair} from "sudoswap/Pair.sol";
import {PairETH} from "sudoswap/PairETH.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

contract PairEnumerableETHTest is ERC721TokenReceiver, LinearBase {
    IERC721 private constant AZUKI =
        IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);
    address private constant AZUKI_OWNER =
        0x2aE6B0630EBb4D155C6e04fCB16840FFA77760AA;

    PairETH private immutable pair;

    constructor() {
        vm.prank(AZUKI_OWNER);

        AZUKI.safeTransferFrom(AZUKI_OWNER, address(this), 0);

        assertTrue(AZUKI.ownerOf(0) == address(this));

        uint256[] memory initialNFTIDs = new uint256[](1);
        initialNFTIDs[0] = 0;

        AZUKI.setApprovalForAll(address(pairFactory), true);

        pair = pairFactory.createPairETH(
            // IERC721 _nft,
            AZUKI,
            // ICurve _bondingCurve,
            linearCurve,
            // address payable _assetRecipient,
            payable(address(0)),
            // Pair.PoolType _poolType,
            Pair.PoolType.TRADE,
            // uint128 _delta,
            1 ether,
            // uint96 _fee,
            0,
            // uint128 _spotPrice,
            1 ether,
            // uint256[] calldata _initialNFTIDs
            initialNFTIDs
        );
    }
}
