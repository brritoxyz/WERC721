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
        // Seller address
        address seller;
        // Adequate for 2.8m ether since the denomination is 0.00000001 ETH
        uint48 price;
        // Optional tip amount - deducted from the sales proceeds
        uint48 tip;
    }

    // Price and tips are denominated in 0.00000001 ETH to tightly pack the struct
    uint256 public constant VALUE_DENOM = 0.00000001 ether;

    ERC721 public collection;

    address payable public tipRecipient;

    mapping(uint256 => Listing) public listings;

    event Initialize(address owner, ERC721 collection);
    event SetTipRecipient(address tipRecipient);
    event List(uint256 indexed id);
    event Edit(uint256 indexed id);
    event Cancel(uint256 indexed id);
    event Buy(uint256 indexed id);

    error Zero();
    error Invalid();
    error Unauthorized();
    error Nonexistent();
    error Insufficient();

    constructor() Owned(msg.sender) {
        // Disable initialization on the implementation contract
        _disableInitializers();
    }

    function _calculateTransferValues(
        uint256 price,
        uint256 tip
    ) private pure returns (uint256 priceETH, uint256 salesProceeds) {
        priceETH = price * VALUE_DENOM;
        salesProceeds = priceETH - (tip * VALUE_DENOM);
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
        // The owner *only* has the ability to set the URI and change the tip recipient
        owner = _owner;

        // Initialize ReentrancyGuard by setting `locked` to unlocked (i.e. 1)
        locked = 1;

        // Initialize this contract with the ERC721 collection contract
        collection = _collection;

        emit Initialize(_owner, _collection);
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function setTipRecipient(address payable _tipRecipient) external onlyOwner {
        tipRecipient = _tipRecipient;

        emit SetTipRecipient(_tipRecipient);
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
     * @param  price  uint48   Price
     * @param  tip    uint48   Tip amount
     */
    function list(uint256 id, uint48 price, uint48 tip) external {
        // Reverts if msg.sender does not have the token
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Revert if the price is zero
        if (price == 0) revert Zero();

        // Revert if the tip is greater than the price
        if (price < tip) revert Invalid();

        // Update token owner to this contract to prevent double-listing
        ownerOf[id] = address(this);

        // Set the listing
        listings[id] = Listing(msg.sender, price, tip);

        emit List(id);
    }

    /**
     * @notice Edit a listing
     * @param  id        uint256  Collection token ID
     * @param  newPrice  uint48   New price
     */
    function edit(uint256 id, uint48 newPrice) external {
        // Revert if the new price is zero
        if (newPrice == 0) revert Zero();

        Listing storage listing = listings[id];

        // Reverts if msg.sender is not the seller or listing does not exist
        if (listing.seller != msg.sender) revert Unauthorized();

        listing.price = newPrice;

        emit Edit(id);
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

        emit Cancel(id);
    }

    /**
     * @notice Fulfill a listing
     * @param  id  uint256  Collection token ID
     */
    function buy(uint256 id) external payable nonReentrant {
        // Reverts if zero value was sent
        if (msg.value == 0) revert Zero();

        Listing memory listing = listings[id];
        (uint256 priceETH, uint256 salesProceeds) = _calculateTransferValues(
            listing.price,
            listing.tip
        );

        // Revert if the listing does not exist (listing price cannot be zero)
        if (priceETH == 0) revert Nonexistent();

        // Reverts if the msg.value does not cover the listing price in ETH
        if (msg.value < priceETH) revert Insufficient();

        // Delete listing prior to setting the token to the buyer
        delete listings[id];

        // Set the new token owner to the buyer
        ownerOf[id] = msg.sender;

        // Transfer the sales proceeds to the seller
        payable(listing.seller).safeTransferETH(salesProceeds);

        // Transfer the tip to the designated recipient, if any. Value
        // sent may contain a buyer tip, which is why we are checking
        // the difference between msg.value and the sales proceeds
        if (msg.value - salesProceeds != 0)
            tipRecipient.safeTransferETH(msg.value - salesProceeds);

        emit Buy(id);
    }
}
