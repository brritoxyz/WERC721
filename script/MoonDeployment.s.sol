// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {MoonDeployment} from "src/MoonDeployment.sol";

contract MoonDeploymentScript is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Contract address is logged in deployment tx receipt
        new MoonDeployment(vm.envAddress("OWNER"));

        vm.stopBroadcast();
    }
}
