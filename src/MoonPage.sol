// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Owned} from "src/base/Owned.sol";
import {ReentrancyGuard} from "src/base/ReentrancyGuard.sol";
import {ERC1155, ERC1155TokenReceiver} from "src/base/ERC1155.sol";

contract MoonPage is
    Initializable,
    Owned,
    ReentrancyGuard,
    ERC721TokenReceiver,
    ERC1155
{
    using SafeTransferLib for address payable;

    struct Listing {
        address seller;
        uint96 price;
    }

    ERC721 public collection;

    mapping(uint256 => Listing) public listings;

    event List(uint256 indexed id, address indexed seller, uint96 price);
    event Edit(uint256 indexed id, address indexed seller, uint96 newPrice);
    event Cancel(uint256 indexed id, address indexed seller);
    event Buy(
        uint256 indexed id,
        address indexed buyer,
        address indexed seller,
        uint96 price
    );

    error Zero();
    error Invalid();
    error Unauthorized();
    error Nonexistent();
    error Insufficient();

    constructor() Owned(msg.sender) {
        // Disable initialization on the implementation contract
        _disableInitializers();
    }

    /**
     * @notice Initializes the minimal proxy with an owner and collection contract
     * @param  _owner       address  Contract owner (has permission to set URI)
     * @param  _collection  ERC721   Collection contract
     */
    function initialize(
        address _owner,
        ERC721 _collection
    ) external initializer {
        // Initialize Owned by setting `owner` to protocol-controlled address
        owner = _owner;

        // Initialize ReentrancyGuard by setting `locked` to unlocked (i.e. 1)
        locked = 1;

        // Initialize this contract with the ERC721 collection contract
        collection = _collection;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    /**
     * @notice Deposit a NFT into the vault and receive a redeemable derivative token
     * @param  id         uint256  Collection token ID
     * @param  recipient  address  Derivative token recipient
     */
    function deposit(uint256 id, address recipient) external nonReentrant {
        if (recipient == address(0)) revert Zero();

        // Transfer the NFT to self before minting the derivative token
        // Reverts if unapproved or if msg.sender does not have the token
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Mint the derivative token for the specified recipient
        // Reverts if the recipient is unsafe, emits TransferSingle
        _mint(recipient, id);
    }

    /**
     * @notice Batch deposit
     * @param  ids        uint256[]  Collection token IDs
     * @param  recipient  address    Derivative token recipient
     */
    function batchDeposit(
        uint256[] calldata ids,
        address recipient
    ) external nonReentrant {
        uint256 iLen = ids.length;

        if (iLen == 0) revert Zero();
        if (recipient == address(0)) revert Zero();

        uint256 id;
        uint256[] memory amounts = new uint256[](iLen);

        for (uint256 i; i < iLen; ) {
            id = ids[i];

            // Transfer the NFT to self before minting the derivative token
            // Reverts if unapproved or if msg.sender does not have the token
            collection.safeTransferFrom(msg.sender, address(this), id);

            // Mint the derivative token for the specified recipient
            ownerOf[id] = recipient;

            // Set the `amounts` element to ONE - emitted in the TransferBatch event
            amounts[i] = ONE;

            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), recipient, ids, amounts);

        require(
            recipient.code.length == 0
                ? recipient != address(0)
                : ERC1155TokenReceiver(recipient).onERC1155BatchReceived(
                    msg.sender,
                    address(0),
                    ids,
                    amounts,
                    EMPTY_DATA
                ) == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id         uint256  Collection token ID
     * @param  recipient  address  Derivative token recipient
     */
    function withdraw(uint256 id, address recipient) external nonReentrant {
        if (recipient == address(0)) revert Zero();

        // Revert if msg.sender is not the owner of the derivative token
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Burn the derivative token before transferring the NFT to the recipient
        _burn(msg.sender, id);

        // Transfer the NFT to the recipient
        collection.safeTransferFrom(address(this), recipient, id);
    }

    /**
     * @notice Batch withdraw
     * @param  ids        uint256[]  Collection token IDs
     * @param  recipient  address    Derivative token recipient
     */
    function batchWithdraw(
        uint256[] calldata ids,
        address recipient
    ) external nonReentrant {
        uint256 iLen = ids.length;

        if (iLen == 0) revert Zero();
        if (recipient == address(0)) revert Zero();

        uint256 id;
        uint256[] memory amounts = new uint256[](iLen);

        for (uint256 i; i < iLen; ) {
            id = ids[i];

            // Revert if msg.sender is not the owner of the derivative token
            if (ownerOf[id] != msg.sender) revert Unauthorized();

            // Burn the derivative token before transferring the NFT to the recipient
            ownerOf[id] = address(0);

            // Set the `amounts` element to ONE - emitted in the TransferBatch event
            amounts[i] = ONE;

            // Transfer the NFT to the recipient
            collection.safeTransferFrom(address(this), recipient, id);

            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, msg.sender, address(0), ids, amounts);
    }

    /**
     * @notice Create a listing
     * @param  id     uint256  Collection token ID
     * @param  price  uint96   Price
     */
    function list(uint256 id, uint96 price) external {
        // Reverts if msg.sender does not have the token
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Revert if the price is zero
        if (price == 0) revert Zero();

        // Update token owner to this contract to prevent double-listing
        ownerOf[id] = address(this);

        // Set the listing
        listings[id] = Listing(msg.sender, price);

        emit List(id, msg.sender, price);
    }

    /**
     * @notice Edit a listing
     * @param  id        uint256  Collection token ID
     * @param  newPrice  uint96   New price
     */
    function edit(uint256 id, uint96 newPrice) external {
        // Revert if the new price is zero
        if (newPrice == 0) revert Zero();

        Listing storage listing = listings[id];

        // Reverts if msg.sender is not the seller or listing does not exist
        if (listing.seller != msg.sender) revert Unauthorized();

        // Update the listing price
        listing.price = newPrice;

        emit Edit(id, msg.sender, newPrice);
    }

    /**
     * @notice Cancel a listing
     * @param  id  uint256  Collection token ID
     */
    function cancel(uint256 id) external {
        // Reverts if msg.sender is not the seller
        if (listings[id].seller != msg.sender) revert Unauthorized();

        // Delete listing prior to returning the token
        delete listings[id];

        ownerOf[id] = msg.sender;

        emit Cancel(id, msg.sender);
    }

    /**
     * @notice Fulfill a listing
     * @param  id  uint256  Collection token ID
     */
    function buy(uint256 id) external payable nonReentrant {
        // Reverts if zero value was sent
        if (msg.value == 0) revert Zero();

        Listing memory listing = listings[id];

        // Reverts if the msg.value does not cover the price or if the
        // listing does not exist (listings cannot have a zero price)
        if (msg.value != listing.price) revert Insufficient();

        // Delete listing prior to returning the token
        delete listings[id];

        // Set the new token owner to the buyer
        ownerOf[id] = msg.sender;

        // Transfer ETH to the seller
        payable(listing.seller).safeTransferETH(msg.value);

        emit Buy(id, msg.sender, listing.seller, listing.price);
    }
}
