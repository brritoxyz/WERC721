// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {ERC2981} from "openzeppelin/token/common/ERC2981.sol";
import {RoyaltyRegistry} from "src/lib/RoyaltyRegistry.sol";

// Gives more realistic scenarios where swaps have to go through multiple pools, for more accurate gas profiling
contract TestRoyaltyRegistry is RoyaltyRegistry {

}
