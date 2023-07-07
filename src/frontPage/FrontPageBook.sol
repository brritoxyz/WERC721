// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Book} from "src/Book.sol";
import {FrontPage} from "src/frontPage/FrontPage.sol";
import {FrontPageERC721} from "src/frontPage/FrontPageERC721.sol";

contract FrontPageBook is Book {
    struct CloneArgs {
        string name;
        string symbol;
        address payable creator;
        uint256 maxSupply;
        uint256 mintPrice;
    }

    // Current ERC-721 collection implementation version
    uint256 public currentCollectionVersion;

    // Version numbers mapped to ERC-721 collection implementation addresses
    mapping(uint256 => address) public collectionImplementations;

    event UpgradeCollection(uint256 version, address implementation);
    event CreateFrontPage(
        address indexed page,
        uint256 indexed collectionVersion,
        uint256 indexed pageVersion
    );

    error InvalidCollectionVersion();
    error InvalidPageVersion();

    /**
     * @notice Increment the version and deploy a new implementation to that version
     * @param  salt            bytes32  CREATE2 salt
     * @param  bytecode        bytes    New ERC-721 contract init code
     * @return version         uint256  New version
     * @return implementation  address  New ERC-721 contract implementation address
     */
    function upgradeCollection(
        bytes32 salt,
        bytes memory bytecode
    )
        external
        payable
        onlyOwner
        returns (uint256 version, address implementation)
    {
        implementation = _create2(salt, bytecode);

        // Increment the current version number - overflow is unrealistic since
        // the cost would be exorbitant for the contract owner, even on an L2
        unchecked {
            version = ++currentCollectionVersion;
        }

        collectionImplementations[version] = implementation;

        emit UpgradeCollection(version, implementation);
    }

    /**
     * @notice Creates a new FrontPage contract
     */
    function createPage(
        CloneArgs calldata args,
        uint256 collectionVersion,
        uint256 pageVersion,
        bytes32 collectionSalt,
        bytes32 pageSalt
    ) external payable returns (address collection, address page) {
        address collectionImplementation = collectionImplementations[
            collectionVersion
        ];
        address pageImplementation = pageImplementations[pageVersion];

        // Revert if the versions are invalid (i.e. implementations are non-existent)
        if (collectionImplementation == address(0))
            revert InvalidCollectionVersion();
        if (pageImplementation == address(0)) revert InvalidPageVersion();

        // TODO: Consider using CWIA for the collection clones after FrontPage is done
        collection = LibClone.cloneDeterministic(
            collectionImplementation,
            collectionSalt
        );

        // Create a minimal proxy for the implementation
        page = LibClone.cloneDeterministic(
            pageImplementation,
            abi.encodePacked(
                collection,
                args.creator,
                args.maxSupply,
                args.mintPrice
            ),
            pageSalt
        );

        // Initialize clones
        FrontPage(page).initialize();
        FrontPageERC721(collection).initialize(
            page,
            args.creator,
            args.name,
            args.symbol
        );

        emit CreateFrontPage(page, collectionVersion, pageVersion);
    }
}
