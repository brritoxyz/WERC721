// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {FrontPageReader} from "src/FrontPageReader.sol";

contract RumasReaderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        FrontPageReader reader = new FrontPageReader(vm.envAddress("FRONT_PAGE"));

        console.log("reader", address(reader));

        vm.stopBroadcast();
    }
}

