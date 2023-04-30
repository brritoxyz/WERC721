// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {MoonBook} from "src/MoonBookV2.sol";

contract MoonDeploymentScript is Script {
    ERC20 private constant STAKER =
        ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ERC4626 private constant VAULT =
        ERC4626(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Contract address is logged in deployment tx receipt
        new MoonBook(STAKER, VAULT, LLAMA);

        vm.stopBroadcast();
    }
}
