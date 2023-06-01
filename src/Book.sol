// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";

interface IPage {
    function initialize() external;
}

contract Book is Ownable {
    // Paired with the collection address to compute the CREATE2 salt
    bytes12 public constant SALT_FRAGMENT = "JPAGE||EGAPJ";

    // Current page implementation version
    uint256 public currentVersion;

    // Versioned Page contract implementation addresses
    mapping(uint256 => address) public pageImplementations;

    // Page implementation mapped to their ERC721 collections and associated Page contracts
    mapping(address => mapping(ERC721 => address)) public pages;

    event UpgradePage(uint256 version, address implementation);
    event CreatePage(
        address indexed implementation,
        ERC721 indexed collection,
        address page
    );

    error Zero();
    error AlreadyExists();

    // Removes opcodes for checking whether msg.value is non-zero during deployment
    constructor() payable {}

    /**
     * @notice Increment the version and deploy a new implementation to that version
     * @param  salt            bytes32  CREATE2 salt
     * @param  bytecode        bytes    New Page contract init code
     * @return version         uint256  New version
     * @return implementation  address  New Page contract implementation address
     */
    function upgradePage(
        bytes32 salt,
        bytes memory bytecode
    )
        external
        payable
        onlyOwner
        returns (uint256 version, address implementation)
    {
        if (bytecode.length == 0) revert Zero();

        // Increment the current version number - overflow is unrealistic since the cost
        // would be exorbitant for the contract owner, even on a L2
        unchecked {
            version = ++currentVersion;
        }

        assembly {
            implementation := create2(
                callvalue(),
                add(bytecode, 0x20),
                mload(bytecode),
                salt
            )
        }

        // Revert if the deployment failed (e.g. same bytecode and salt)
        if (implementation == address(0)) revert Zero();

        pageImplementations[version] = implementation;

        emit UpgradePage(version, implementation);
    }

    /**
     * @notice Creates a new Page contract (minimal proxy) for the given implementation and collection
     * @param  collection  ERC721   NFT collection
     * @return page        address  Page contract address
     */
    function createPage(ERC721 collection) external payable returns (address page) {
        // Revert if the collection is the zero address
        if (address(collection) == address(0)) revert Zero();

        address implementation = pageImplementations[currentVersion];

        // Create a minimal proxy for the implementation
        page = LibClone.cloneDeterministic(
            implementation,
            abi.encodePacked(address(collection)),
            keccak256(
                abi.encodePacked(collection, SALT_FRAGMENT, block.timestamp)
            )
        );

        // Only store pages if they don't already exist, otherwise, return the address and emit the
        // event in order to signify that a new Page contract was deployed. By enabling multiple, "non-canonical"
        // deployments, we're able to circumvent censorship by collections and other actors
        if (pages[implementation][collection] == address(0)) {
            // Update the mapping to point the collection to its page
            pages[implementation][collection] = page;
        }

        emit CreatePage(implementation, collection, page);

        // Initialize the minimal proxy's state variables
        IPage(page).initialize();
    }
}
