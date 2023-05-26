// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {Book} from "src/Book.sol";
import {Page} from "src/Page.sol";

contract DeploymentScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Book book = new Book();

        // Page implementation version is currentVersion (i.e. 0) + 1
        // Since this is the first implementation, the version is 1
        (uint256 version, address implementation) = book.upgradePage(
            keccak256("VERSION_1"),
            type(Page).creationCode
        );

        require(version == 1, "INVALID VERSION");
        require(implementation != address(0), "INVALID IMPLEMENTATION");

        console.log(address(book));
        console.log(implementation);

        vm.stopBroadcast();
    }
}
