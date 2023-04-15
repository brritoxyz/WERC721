// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {MoonDeployment} from "src/MoonDeployment.sol";

contract MoonDeploymentScript is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MoonDeployment deployment = new MoonDeployment(vm.envAddress("OWNER"));

        // Log key contract addresses
        console.log("MoonDeployment:", address(deployment));
        console.log("Moon:", address(deployment.moon()));
        console.log("MoonBookFactory:", address(deployment.factory()));

        vm.stopBroadcast();
    }
}
