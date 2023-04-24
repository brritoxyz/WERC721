// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {Moon} from "src/Moon.sol";
import {MoonBookFactory} from "src/MoonBookFactory.sol";

contract MoonDeployment {
    ERC20 private constant STAKER =
        ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ERC4626 private constant VAULT =
        ERC4626(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);

    Moon public immutable moon;
    MoonBookFactory public immutable factory;

    constructor(address owner) {
        // Temporarily set owner to the deployer contract until configuration is complete
        moon = new Moon(STAKER, VAULT);

        factory = new MoonBookFactory(moon);

        // Transfer token ownership to designated account
        moon.transferOwnership(owner);
    }
}
