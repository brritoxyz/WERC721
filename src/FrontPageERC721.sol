// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

contract FrontPageERC721 is Ownable, ERC721 {
    string public baseURI;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC721(_name, _symbol) {
        _initializeOwner(_owner);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, LibString.toString(id)));
    }
}
