// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {Owned} from "src/base/Owned.sol";
import {Page} from "src/Page.sol";

contract Book is Owned {
    // Paired with the collection address to compute the CREATE2 salt
    bytes12 public constant SALT_FRAGMENT = bytes12("JPAGE||EGAPJ");

    // Page implementation contract address
    address public immutable pageImplementation;

    // Current page implementation version
    uint96 public currentVersion;

    // Tip recipient used when initializing pages
    address payable public tipRecipient;

    mapping(uint256 version => address implementation)
        public pageImplementations;

    // ERC721 collections mapped to their Page contracts
    mapping(ERC721 => address) public pages;

    event UpgradePage(uint256 version, address implementation);
    event SetTipRecipient(address tipRecipient);

    error Zero();
    error AlreadyExists();

    constructor(address payable _tipRecipient) Owned(msg.sender) {
        if (_tipRecipient == address(0)) revert Zero();

        pageImplementation = address(new Page());
        tipRecipient = _tipRecipient;

        // Set the initial page implementation at the first version
        pageImplementations[currentVersion] = pageImplementation;
    }

    /**
     * @notice Increment the version and deploy a new implementation to that number
     * @param  bytecode  bytes  New Page contract init code
     */
    function upgradePage(
        bytes memory bytecode
    ) external payable onlyOwner returns (address implementation) {
        if (bytecode.length == 0) revert Zero();

        // Increment the current version number - will not overflow since the cost to do so
        // is more than anyone can ever afford
        unchecked {
            ++currentVersion;
        }

        bytes32 salt = keccak256(
            abi.encodePacked(address(this), SALT_FRAGMENT)
        );

        assembly {
            implementation := create2(
                callvalue(), // wei sent with current call
                // Actual code starts after skipping the first 32 bytes
                add(bytecode, 0x20),
                mload(bytecode), // Load the size of code contained in the first 32 bytes
                salt // Salt from function arguments
            )
        }

        // Revert if the deployment failed (e.g. same bytecode and salt)
        if (implementation == address(0)) revert Zero();

        pageImplementations[currentVersion] = implementation;

        emit UpgradePage(currentVersion, implementation);
    }

    /**
     * @notice Sets the tip recipient
     * @param  _tipRecipient  address  Tip recipient (receives optional tips)
     */
    function setTipRecipient(address payable _tipRecipient) external onlyOwner {
        if (_tipRecipient == address(0)) revert Zero();

        tipRecipient = _tipRecipient;

        emit SetTipRecipient(_tipRecipient);
    }

    /**
     * @notice Creates a new Page contract (minimal proxy) for the given collection
     * @param  collection  ERC721   NFT collection
     * @return page        address  Page contract address
     */
    function createPage(ERC721 collection) external returns (address page) {
        // Revert if the collection is the zero address
        if (address(collection) == address(0)) revert Zero();

        // Prevent pages from being re-deployed and overwritten
        if (pages[collection] != address(0)) revert AlreadyExists();

        page = Clones.cloneDeterministic(
            pageImplementation,
            keccak256(abi.encodePacked(collection, SALT_FRAGMENT))
        );

        // Initialize minimal proxy with the owner and collection
        Page(page).initialize(owner, collection, tipRecipient);

        // Update the mapping to point the collection to its page
        pages[collection] = page;
    }
}
