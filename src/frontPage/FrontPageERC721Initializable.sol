// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";

contract FrontPageERC721Initializable is Ownable, ERC721 {
    bool private _initialized;
    string private _name;
    string private _symbol;

    address public frontPage;
    string public baseURI;

    error ZeroAddress();
    error EmptyString();
    error AlreadyInitialized();

    constructor() payable {
        // Prevent the implementation contract from being initialized
        _initialized = true;
    }

    function initialize(
        address _owner,
        address _frontPage,
        string calldata collectionName,
        string calldata collectionSymbol
    ) external payable {
        if (_initialized) revert AlreadyInitialized();
        if (_owner == address(0)) revert ZeroAddress();
        if (_frontPage == address(0)) revert ZeroAddress();
        if (bytes(collectionName).length == 0) revert EmptyString();
        if (bytes(collectionSymbol).length == 0) revert EmptyString();

        // Set _initialized to true to prevent subsequent calls
        _initialized = true;

        // Set the contract owner, who has the ability to set the baseURI
        _initializeOwner(_owner);

        // Set the FrontPage contract, which facilitates J.Page token => ERC-721 redemptions
        frontPage = _frontPage;

        // Set the collection name and symbol which are publicly accessible via the name and symbol methods
        _name = collectionName;
        _symbol = collectionSymbol;
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
