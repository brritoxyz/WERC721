// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

contract FrontPageERC721 is Ownable, ERC721 {
    address public immutable frontPage;

    string public baseURI;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC721(_name, _symbol) {
        // Set the FrontPage contract (i.e. the deployer of this contract)
        frontPage = msg.sender;

        // Enable the creator to update the baseURI
        _initializeOwner(_owner);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, LibString.toString(id)));
    }

    function mint(address to, uint256 id) external {
        // Users must redeem through the FrontPage contract, the only authorized caller of this method
        // since FrontPage contract "burns" the FP token ID prior to minting the NFT, preventing reuse
        if (msg.sender != frontPage) revert Unauthorized();

        _mint(to, id);
    }

    function batchMint(address to, uint256[] calldata ids) external {
        if (msg.sender != frontPage) revert Unauthorized();

        for (uint256 i; i < ids.length; ) {
            _mint(to, ids[i]);

            unchecked {
                ++i;
            }
        }
    }
}
