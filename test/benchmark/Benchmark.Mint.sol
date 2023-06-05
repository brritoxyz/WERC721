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
}

contract TestERC721 is ERC721("Test", "TEST") {
    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract TestERC721A is ERC721A("Test", "TEST") {
    function mint(address to, uint256 quantity) external {
        _mint(to, quantity);
    }
}

contract TestFrontPageERC721 is FrontPageERC721 {
    constructor(
        address _owner,
        uint256 _maxSupply
    ) payable FrontPageERC721("Test", "TEST", _owner, _maxSupply) {}
}

contract BenchmarkMint is Test {
    TestERC721Enumerable private immutable erc721Enumerable;
    TestERC721 private immutable erc721;
    TestERC721A private immutable erc721A;
    TestFrontPageERC721 private immutable frontPageERC721;

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

    function testERC721EnumerableMint() external {
        erc721Enumerable.mint(address(this), 0);
    }

    function testERC721Mint() external {
        erc721.mint(address(this), 0);
    }

    function testERC721AMint() external {
        erc721A.mint(address(this), 1);
    }

    function testFrontPageERC721Mint() external {
        frontPageERC721.mint(address(this), 0);
    }
}
