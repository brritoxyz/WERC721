// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {FrontPage} from "src/frontPage/FrontPage.sol";
import {FrontPageReader} from "src/frontPage/FrontPageReader.sol";

contract RumasDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory name = "JPAGE Rumas";
        string memory symbol = "RUMAS";
        address payable creator = payable(vm.envAddress("CREATOR"));
        uint256 maxSupply = 12_345;
        uint256 mintPrice = 0.069 ether;

        FrontPage page = new FrontPage(
            name,
            symbol,
            creator,
            maxSupply,
            mintPrice
        );
        FrontPageReader reader = new FrontPageReader(address(page));

        console.log("page", address(page));
        console.log("collection", address(page.collection()));
        console.log("reader", address(reader));

        vm.stopBroadcast();
    }
}
