// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {ERC1155 as _MoonERC1155} from "src/base/ERC1155.sol";

contract SolmateERC1155 is ERC1155 {
    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(uint256 id) external {
        _mint(msg.sender, id, 1, "");
    }

    function batchMint(
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        _batchMint(msg.sender, ids, amounts, "");
    }
}

contract MoonERC1155 is _MoonERC1155 {
    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(uint256 id) external {
        _mint(msg.sender, id);
    }

    function batchMint(uint256[] calldata ids) external {
        for (uint256 i; i < ids.length; ) {
            _mint(msg.sender, ids[i]);

            unchecked {
                ++i;
            }
        }
    }
}

contract SafeTransferFromTest is
    Test,
    ERC1155TokenReceiver,
    ERC721TokenReceiver
{
    ERC721 private constant ERC721_VYPER =
        ERC721(0xe127cE638293FA123Be79C25782a5652581Db234);

    ERC721 private constant ERC721A =
        ERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);

    SolmateERC1155 private immutable base = new SolmateERC1155();
    MoonERC1155 private immutable moon = new MoonERC1155();

    address private constant RECEIVER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Fixed test data for batch operations
    uint256[] private ids = [0, 1, 2];
    uint256[] private amounts = [1, 1, 1];
    address[] private originalOwners = [
        address(this),
        address(this),
        address(this)
    ];
    address[] private newOwners = [RECEIVER, RECEIVER, RECEIVER];
    uint256[] private fullBalance = [1, 1, 1];
    uint256[] private emptyBalance = [0, 0, 0];

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function testERC721VyperSafeTransferFrom() external {
        uint256 id = 0;

        address originalOwner = ERC721_VYPER.ownerOf(id);

        vm.prank(originalOwner);

        ERC721_VYPER.safeTransferFrom(originalOwner, RECEIVER, id);
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721A LOGIC
    //////////////////////////////////////////////////////////////*/

    function testERC721ASafeTransferFrom() external {
        uint256 id = 0;

        address originalOwner = ERC721A.ownerOf(id);

        vm.prank(originalOwner);

        ERC721A.safeTransferFrom(originalOwner, RECEIVER, id);
    }

    /*//////////////////////////////////////////////////////////////
                              SolmateERC1155
    //////////////////////////////////////////////////////////////*/

    function testBaseSafeTransferFrom() external {
        uint256 id = 0;

        base.mint(id);

        assertEq(1, base.balanceOf(address(this), id));
        assertEq(0, base.balanceOf(RECEIVER, id));

        base.safeTransferFrom(address(this), RECEIVER, id, 1, "");

        assertEq(0, base.balanceOf(address(this), id));
        assertEq(1, base.balanceOf(RECEIVER, id));
    }

    function testBaseSafeBatchTransferFrom() external {
        base.batchMint(ids, amounts);

        assertEq(fullBalance, base.balanceOfBatch(originalOwners, ids));
        assertEq(emptyBalance, base.balanceOfBatch(newOwners, ids));

        base.safeBatchTransferFrom(address(this), RECEIVER, ids, amounts, "");

        assertEq(emptyBalance, base.balanceOfBatch(originalOwners, ids));
        assertEq(fullBalance, base.balanceOfBatch(newOwners, ids));
    }

    /*//////////////////////////////////////////////////////////////
                              MoonERC1155
    //////////////////////////////////////////////////////////////*/

    function testMoonSafeTransferFrom() external {
        uint256 id = 0;

        moon.mint(id);

        assertEq(1, moon.balanceOf(address(this), id));
        assertEq(0, moon.balanceOf(RECEIVER, id));

        moon.safeTransferFrom(address(this), RECEIVER, id, 1, "");

        assertEq(0, moon.balanceOf(address(this), id));
        assertEq(1, moon.balanceOf(RECEIVER, id));
    }

    function testMoonSafeBatchTransferFrom() external {
        moon.batchMint(ids);

        assertEq(fullBalance, moon.balanceOfBatch(originalOwners, ids));
        assertEq(emptyBalance, moon.balanceOfBatch(newOwners, ids));

        moon.safeBatchTransferFrom(address(this), RECEIVER, ids, amounts, "");

        assertEq(emptyBalance, moon.balanceOfBatch(originalOwners, ids));
        assertEq(fullBalance, moon.balanceOfBatch(newOwners, ids));
    }
}
