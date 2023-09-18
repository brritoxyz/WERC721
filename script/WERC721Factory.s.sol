// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {WERC721Factory} from "src/WERC721Factory.sol";

contract WERC721FactoryScript is Script {
    function run() external {
        vm.broadcast(vm.envUint("PRIVATE_KEY"));

        new WERC721Factory();
    }
}
