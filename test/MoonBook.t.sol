// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {Moon} from "src/Moon.sol";
import {MoonBookFactory} from "src/MoonBookFactory.sol";
import {MoonBook} from "src/MoonBook.sol";

contract MoonBookTest is Test {
    ERC20 private constant STAKER =
        ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ERC4626 private constant VAULT =
        ERC4626(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    Moon private immutable moon;
    MoonBookFactory private immutable factory;
    MoonBook private immutable book;

    event CreateMoonBook(address indexed msgSender, ERC721 indexed collection);

    constructor() {
        moon = new Moon(STAKER, VAULT);
        factory = new MoonBookFactory(moon);
        book = factory.createMoonBook(LLAMA);
    }

    /*//////////////////////////////////////////////////////////////
                            createMoonBook
    //////////////////////////////////////////////////////////////*/

    function testCannotCreateMoonBookAlreadyExists() external {
        vm.expectRevert(MoonBookFactory.AlreadyExists.selector);

        factory.createMoonBook(LLAMA);
    }

    function testCreateMoonBook(address msgSender, ERC721 collection) external {
        vm.assume(address(collection) != address(0));
        vm.assume(address(collection) != address(LLAMA));

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(factory));

        emit CreateMoonBook(msgSender, collection);

        MoonBook moonBook = factory.createMoonBook(collection);

        assertEq(address(moonBook), address(factory.moonBooks(collection)));
    }
}
