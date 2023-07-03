// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {PageToken} from "src/PageToken.sol";

contract PageTokenImpl is PageToken {
    function name() external pure override returns (string memory) {
        return "Page";
    }

    function symbol() external pure override returns (string memory) {
        return "PAGE";
    }

    function tokenURI(uint256) external pure override returns (string memory) {
        return "";
    }

    function setOwnerOf(uint256 id, address owner) external {
        ownerOf[id] = owner;
    }
}

contract PageTokenTest is Test {
    PageTokenImpl private immutable pageToken = new PageTokenImpl();

    address[] internal accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    /*//////////////////////////////////////////////////////////////
                             setApprovalForAll
    //////////////////////////////////////////////////////////////*/

    function testSetApprovalForAllFalseToTrue() external {
        assertTrue(!pageToken.isApprovedForAll(address(this), accounts[0]));

        pageToken.setApprovalForAll(accounts[0], true);

        assertTrue(pageToken.isApprovedForAll(address(this), accounts[0]));
    }

    function testSetApprovalForAllTrueToFalse() external {
        pageToken.setApprovalForAll(accounts[0], true);

        assertTrue(pageToken.isApprovedForAll(address(this), accounts[0]));

        pageToken.setApprovalForAll(accounts[0], false);

        assertTrue(!pageToken.isApprovedForAll(address(this), accounts[0]));
    }

    function testSetApprovalForAllFuzz(
        address operator,
        bool approved
    ) external {
        pageToken.setApprovalForAll(operator, approved);

        assertEq(approved, pageToken.isApprovedForAll(address(this), operator));
    }
}
