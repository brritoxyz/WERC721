// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MoonBook} from "src/MoonBook.sol";
import {MoonPage} from "src/MoonPage.sol";

contract DummyERC20 is ERC20("", "", 18) {}

contract DummyERC4626 is ERC4626(new DummyERC20(), "", "") {
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}

contract MoonBookTest is Test {
    ERC721 private constant LLAMA =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    MoonBook private immutable moon;
    MoonPage private immutable page;
    address private immutable moonAddr;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor() {
        moon = new MoonBook();
        moonAddr = address(moon);

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            moon.pageImplementation(),
            keccak256(abi.encodePacked(LLAMA, moon.SALT_FRAGMENT())),
            address(moon)
        );
        address pageAddress = moon.createPage(LLAMA);

        page = MoonPage(pageAddress);

        assertEq(address(this), moon.owner());
        assertEq(address(this), page.owner());
        assertEq(predeterminedPageAddress, pageAddress);
        assertTrue(moon.pageImplementation() != address(0));

        vm.expectRevert("Initializable: contract is already initialized");

        page.initialize(address(this), LLAMA);
    }

    /*//////////////////////////////////////////////////////////////
                             createPage
    //////////////////////////////////////////////////////////////*/

    function testCannotCreatePageCollectionInvalid() external {
        vm.expectRevert(MoonBook.Invalid.selector);

        moon.createPage(ERC721(address(0)));
    }

    function testCannotCreatePageAlreadyCreated() external {
        assertEq(address(page), moon.pages(LLAMA));

        vm.expectRevert(MoonBook.AlreadyExists.selector);

        moon.createPage(LLAMA);
    }

    function testCreatePage(ERC721 collection) external {
        vm.assume(address(collection) != address(0));
        vm.assume(address(collection) != address(LLAMA));

        assertEq(address(0), moon.pages(collection));

        address predeterminedPageAddress = Clones.predictDeterministicAddress(
            moon.pageImplementation(),
            keccak256(abi.encodePacked(collection, moon.SALT_FRAGMENT())),
            address(moon)
        );
        address pageAddress = moon.createPage(collection);

        assertEq(predeterminedPageAddress, pageAddress);
        assertEq(address(this), MoonPage(pageAddress).owner());
        assertEq(
            address(collection),
            address(MoonPage(pageAddress).collection())
        );

        vm.expectRevert("Initializable: contract is already initialized");

        MoonPage(pageAddress).initialize(address(this), collection);
    }
}
