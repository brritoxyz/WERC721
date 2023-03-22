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

    event NFTWithdrawal();

    constructor() {
        uint256[] memory initialNFTIDs = new uint256[](3);
        initialNFTIDs[0] = 0;
        initialNFTIDs[1] = 2;
        initialNFTIDs[2] = 7;

        vm.startPrank(AZUKI_OWNER);

        uint256 iLen = initialNFTIDs.length;

        // Transfer NFTs from owner to self
        for (uint256 i; i < iLen; ) {
            uint256 id = initialNFTIDs[i];

            assertTrue(AZUKI.ownerOf(id) == AZUKI_OWNER);

            AZUKI.safeTransferFrom(AZUKI_OWNER, address(this), id);

            assertTrue(AZUKI.ownerOf(id) == address(this));

            unchecked {
                ++i;
            }
        }

        vm.stopPrank();

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

        // Verify that the pair contract has custody of the NFTs
        for (uint256 i; i < iLen; ) {
            uint256 id = initialNFTIDs[i];

            assertTrue(AZUKI.ownerOf(id) == address(pair));

            unchecked {
                ++i;
            }
        }
    }

    function testWithdrawERC721() external {
        uint256[] memory heldIds = pair.getAllHeldIds();
        IERC721 a = AZUKI;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = heldIds[0];

        assertTrue(AZUKI.ownerOf(nftIds[0]) == address(pair));
        assertTrue(pair.owner() == address(this));

        vm.expectEmit(false, false, false, false, address(pair));

        emit NFTWithdrawal();

        pair.withdrawERC721(a, nftIds);

        assertTrue(AZUKI.ownerOf(nftIds[0]) == address(this));

        uint256[] memory postWithdrawalHeldIds = pair.getAllHeldIds();

        assertEq(heldIds[1], postWithdrawalHeldIds[0]);
        assertEq(heldIds[2], postWithdrawalHeldIds[1]);
        assertEq(heldIds.length - 1, postWithdrawalHeldIds.length);
    }
}
