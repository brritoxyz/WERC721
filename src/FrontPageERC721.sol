// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";

contract FrontPageERC721 is Ownable, ERC721 {
    address public immutable frontPage;
    string public baseURI;
    string private _name;
    string private _symbol;

    constructor(
        string memory metadataName,
        string memory metadataSymbol,
        address _owner
    ) payable {
        // ERC-721 metadata
        _name = metadataName;
        _symbol = metadataSymbol;

        // Set the FrontPage contract (i.e. the deployer of this contract)
        frontPage = msg.sender;

        // Enable the creator to update the baseURI
        _initializeOwner(_owner);
    }

    function setBaseURI(string calldata baseURI_) external payable onlyOwner {
        baseURI = baseURI_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, LibString.toString(id)));
    }

    function mint(address to, uint256 id) external payable {
        // Users must redeem through the FrontPage contract, the only authorized caller of this method
        // since FrontPage burns the FP token ID prior to minting the NFT, preventing reuse
        if (msg.sender != frontPage) revert Unauthorized();

        _mint(to, id);
    }

    function batchMint(address to, uint256[] calldata ids) external payable {
        if (msg.sender != frontPage) revert Unauthorized();

        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            _mint(to, ids[i]);

            unchecked {
                ++i;
            }
        }
    }
}
