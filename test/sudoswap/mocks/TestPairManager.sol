// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {IOwnershipTransferCallback} from "src/interfaces/IOwnershipTransferCallback.sol";

contract TestPairManager is IOwnershipTransferCallback {
    address public prevOwner;

    constructor() {}

    function onOwnershipTransfer(address a) public {
        prevOwner = a;
    }
}
