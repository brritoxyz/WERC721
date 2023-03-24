// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {RouterWithRoyalties} from "sudoswap/RouterWithRoyalties.sol";
import {PairFactory} from "sudoswap/PairFactory.sol";

contract MoonRouter is RouterWithRoyalties {
    constructor(PairFactory _factory) RouterWithRoyalties(_factory) {}
}
