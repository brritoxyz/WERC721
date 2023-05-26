// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";

interface IPage {
    function initialize(ERC721, address payable) external;
}

contract Book is Ownable {
    // Paired with the collection address to compute the CREATE2 salt
    bytes12 public constant SALT_FRAGMENT = "JPAGE||EGAPJ";

    // Tip recipient used when initializing pages
    address payable public tipRecipient;

    // Current page implementation version
    uint256 public currentVersion;

    // Versioned Page contract implementation addresses
    mapping(uint256 version => address implementation)
        public pageImplementations;

    // Page implementation mapped to their ERC721 collections and associated Page contracts
    mapping(address implementation => mapping(ERC721 collection => address page))
        public pages;

    event UpgradePage(uint256 version, address implementation);
    event SetTipRecipient(address tipRecipient);
    event CreatePage(
        address indexed implementation,
        ERC721 indexed collection,
        address page
    );

    error Zero();
    error AlreadyExists();

    constructor(address payable _tipRecipient) {
        if (_tipRecipient == address(0)) revert Zero();

        tipRecipient = _tipRecipient;
    }

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
     * @notice Sets the tip recipient
     * @param  _tipRecipient  address  Tip recipient (receives optional tips)
     */
    function setTipRecipient(address payable _tipRecipient) external onlyOwner {
        if (_tipRecipient == address(0)) revert Zero();

        tipRecipient = _tipRecipient;

        emit SetTipRecipient(_tipRecipient);
    }

    /**
     * @notice Creates a new Page contract (minimal proxy) for the given implementation and collection
     * @param  collection  ERC721   NFT collection
     * @return page        address  Page contract address
     */
    function createPage(ERC721 collection) external returns (address page) {
        // Revert if the collection is the zero address
        if (address(collection) == address(0)) revert Zero();

        address implementation = pageImplementations[currentVersion];

        // Create a minimal proxy for the implementation
        page = Clones.cloneDeterministic(
            implementation,
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

        // Initialize the minimal proxy's state variables
        IPage(page).initialize(collection, tipRecipient);

        emit CreatePage(implementation, collection, page);
    }
}
