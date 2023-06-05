// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC721 as OZ_ERC721, ERC721Enumerable} from "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC721A} from "ERC721A/ERC721A.sol";
import {FrontPageERC721} from "src/FrontPageERC721.sol";

contract TestERC721Enumerable is ERC721Enumerable {
    constructor() payable OZ_ERC721("Test", "TEST") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    // Having this method on the test contract allows us to test the gas cost of 1 call
    // Not necessary on contracts that support batch minting natively (i.e. ERC721A and FrontPageERC721)
    // Needs to be modified for more complex cases where the token ID does not start from 0
    function batchMint(address to, uint256 quantity) external {
        for (uint256 i = 0; i < quantity; ) {
            _mint(to, i);

            unchecked {
                ++i;
            }
        }
    }
}

contract TestERC721 is ERC721("Test", "TEST") {
    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    // Having this method on the test contract allows us to test the gas cost of 1 call
    // Needs to be modified for more complex cases where the token ID does not start from 0
    function batchMint(address to, uint256 quantity) external {
        for (uint256 i = 0; i < quantity; ) {
            _mint(to, i);

            unchecked {
                ++i;
            }
        }
    }
}

contract TestERC721A is ERC721A("Test", "TEST") {
    function mint(address to, uint256 quantity) external {
        _mint(to, quantity);
    }

    // Optional method to make it easier to read on the gas report output
    function batchMint(address to, uint256 quantity) external {
        _mint(to, quantity);
    }
}

contract TestFrontPageERC721 is FrontPageERC721 {
    constructor(
        address _owner,
        uint256 _maxSupply
    ) payable FrontPageERC721("Test", "TEST", _owner, _maxSupply) {}
}

contract BenchmarkBase {
    TestERC721Enumerable internal immutable erc721Enumerable;
    TestERC721 internal immutable erc721;
    TestERC721A internal immutable erc721A;
    TestFrontPageERC721 internal immutable frontPageERC721;

    constructor() {
        erc721Enumerable = new TestERC721Enumerable();
        erc721 = new TestERC721();
        erc721A = new TestERC721A();
        frontPageERC721 = new TestFrontPageERC721(address(this), 10_000);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
