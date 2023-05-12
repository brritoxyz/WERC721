// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Owned} from "src/base/Owned.sol";
import {ReentrancyGuard} from "src/base/ReentrancyGuard.sol";
import {ERC1155NS} from "src/base/ERC1155NS.sol";

contract Page is
    Initializable,
    Owned,
    ReentrancyGuard,
    ERC721TokenReceiver,
    ERC1155NS
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

    // Price and tips are denominated in 0.00000001 ETH
    uint256 public constant VALUE_DENOM = 0.00000001 ether;

    ERC721 public collection;

    address payable public tipRecipient;

    mapping(uint256 => Listing) public listings;

    event Initialize(address owner, ERC721 collection, address tipRecipient);
    event SetTipRecipient(address tipRecipient);
    event List(uint256 id);
    event Edit(uint256 id);
    event Cancel(uint256 id);
    event Buy(uint256 id);
    event BatchList(uint256[] ids);
    event BatchEdit(uint256[] ids);
    event BatchCancel(uint256[] ids);
    event BatchBuy(uint256[] ids);

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
     * @notice Calculates the listing-related values in the specified ETH denomination
     * @param  price           uint256  Listing price
     * @param  tip             uint256  Listing tip
     * @return priceETH        uint256  Listing price in ETH
     * @return sellerProceeds  uint256  Proceeds received by the seller in ETH (listing price - listing tip)
     */
    function _calculateListingValues(
        uint256 price,
        uint256 tip
    ) private pure returns (uint256 priceETH, uint256 sellerProceeds) {
        // Price and tip are upcasted to uint256 from uint48 (i.e. their max value is 2**48 - 1)
        // Knowing that, we can be sure that the below will never overflow since (2**48 - 1) * 1e-8 < (2**256 - 1)
        unchecked {
            priceETH = price * VALUE_DENOM;
            sellerProceeds = priceETH - (tip * VALUE_DENOM);
        }
    }

    /**
     * @notice Deposit a NFT into the vault to mint a redeemable derivative token with the same ID
     * @param  id         uint256  Token ID
     * @param  recipient  address  Derivative token recipient
     */
    function _deposit(uint256 id, address recipient) private {
        // Transfer the NFT to self before minting the derivative token
        // Reverts if unapproved or if msg.sender does not have the token
        collection.transferFrom(msg.sender, address(this), id);

        // Mint the derivative token for the specified recipient (same ID)
        ownerOf[id] = recipient;
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id         uint256  Token ID
     * @param  recipient  address  NFT recipient
     */
    function _withdraw(uint256 id, address recipient) private {
        // Revert if msg.sender is not the owner of the derivative token
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Burn the derivative token before transferring the NFT to the recipient
        ownerOf[id] = address(0);

        // Transfer the NFT to the recipient - reverts if recipient is zero address
        collection.safeTransferFrom(address(this), recipient, id);
    }

    /**
     * @notice Create a listing
     * @param  id     uint256  Token ID
     * @param  price  uint48   Price
     * @param  tip    uint48   Tip amount
     */
    function _list(uint256 id, uint48 price, uint48 tip) private {
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
    }

    /**
     * @notice Edit a listing
     * @param  id        uint256  Token ID
     * @param  newPrice  uint48   New price
     */
    function _edit(uint256 id, uint48 newPrice) private {
        // Revert if the new price is zero
        if (newPrice == 0) revert Zero();

        Listing storage listing = listings[id];

        // Reverts if msg.sender is not the seller or listing does not exist
        if (listing.seller != msg.sender) revert Unauthorized();

        // Revert if the new price is less than the tip
        if (newPrice < listing.tip) revert Invalid();

        listing.price = newPrice;
    }

    /**
     * @notice Cancel a listing
     * @param  id  uint256  Token ID
     */
    function _cancel(uint256 id) private {
        // Reverts if msg.sender is not the seller
        if (listings[id].seller != msg.sender) revert Unauthorized();

        // Delete listing prior to returning the token
        delete listings[id];

        ownerOf[id] = msg.sender;
    }

    /**
     * @notice Initializes the minimal proxy with an owner and collection contract
     * @dev    There is no param validation to save gas (the Book contract will always input non-zero values)
     * @param  _owner         address  Contract owner (has permission to changes the tip recipient)
     * @param  _collection    ERC721   Collection contract
     * @param  _tipRecipient  address  Tip recipient
     */
    function initialize(
        address _owner,
        ERC721 _collection,
        address payable _tipRecipient
    ) external initializer {
        // Initialize Owned by setting `owner` to protocol-controlled address
        // The owner *only* has the ability to set the URI and change the tip recipient
        owner = _owner;

        // Initialize ReentrancyGuard by setting `locked` to unlocked (i.e. 1)
        locked = 1;

        // Initialize this contract with the ERC721 collection contract
        collection = _collection;

        // Initialize this contract with a tip recipient (can later be modified by the owner if needed)
        tipRecipient = _tipRecipient;

        emit Initialize(_owner, _collection, _tipRecipient);
    }

    /**
     * @notice Retrieves the collection token URI for the specified ID
     * @param  id  uint256  Token ID
     * @return     string   Token URI
     */
    function uri(uint256 id) public view override returns (string memory) {
        return collection.tokenURI(id);
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
     * @notice Deposit a NFT into the vault to mint a redeemable derivative token with the same ID
     * @param  id         uint256  Token ID
     * @param  recipient  address  Derivative token recipient
     */
    function deposit(uint256 id, address recipient) external nonReentrant {
        _deposit(id, recipient);
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id         uint256  Token ID
     * @param  recipient  address  NFT recipient
     */
    function withdraw(uint256 id, address recipient) external nonReentrant {
        _withdraw(id, recipient);
    }

    /**
     * @notice Create a listing
     * @param  id     uint256  Token ID
     * @param  price  uint48   Price
     * @param  tip    uint48   Tip amount
     */
    function list(uint256 id, uint48 price, uint48 tip) external {
        _list(id, price, tip);

        emit List(id);
    }

    /**
     * @notice Edit a listing
     * @param  id        uint256  Token ID
     * @param  newPrice  uint48   New price
     */
    function edit(uint256 id, uint48 newPrice) external {
        _edit(id, newPrice);

        emit Edit(id);
    }

    /**
     * @notice Cancel a listing
     * @param  id  uint256  Token ID
     */
    function cancel(uint256 id) external {
        _cancel(id);

        emit Cancel(id);
    }

    /**
     * @notice Fulfill a listing
     * @param  id  uint256  Token ID
     */
    function buy(uint256 id) external payable nonReentrant {
        Listing memory listing = listings[id];

        // Revert if the listing does not exist (listing price cannot be zero)
        if (listing.price == 0) revert Nonexistent();

        (uint256 priceETH, uint256 sellerProceeds) = _calculateListingValues(
            listing.price,
            listing.tip
        );

        // Reverts if the msg.value does not cover the listing price in ETH
        if (msg.value < priceETH) revert Insufficient();

        // Delete listing prior to setting the token to the buyer
        delete listings[id];

        // Set the new token owner to the buyer
        ownerOf[id] = msg.sender;

        // Transfer the sales proceeds to the seller
        payable(listing.seller).safeTransferETH(sellerProceeds);

        // Transfer the tip to the designated recipient, if any. Value
        // sent may contain a buyer tip, which is why we are checking
        // the difference between msg.value and the sales proceeds
        if (msg.value - sellerProceeds != 0)
            tipRecipient.safeTransferETH(msg.value - sellerProceeds);

        emit Buy(id);
    }

    /**
     * @notice Batch deposit
     * @param  ids        uint256[]  Token IDs
     * @param  recipient  address    Derivative token recipient
     */
    function batchDeposit(
        uint256[] calldata ids,
        address recipient
    ) external nonReentrant {
        // If ids.length is zero then the loop body never runs and caller wastes gas
        for (uint256 i; i < ids.length; ) {
            _deposit(ids[i], recipient);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Batch withdraw
     * @param  ids        uint256[]  Token IDs
     * @param  recipient  address    NFT recipient
     */
    function batchWithdraw(
        uint256[] calldata ids,
        address recipient
    ) external nonReentrant {
        for (uint256 i; i < ids.length; ) {
            _withdraw(ids[i], recipient);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Create a batch of listings
     * @param  ids     uint256[]  Token IDs
     * @param  prices  uint48[]   Prices
     * @param  tips    uint48[]   Tip amounts
     */
    function batchList(
        uint256[] calldata ids,
        uint48[] calldata prices,
        uint48[] calldata tips
    ) external {
        for (uint256 i; i < ids.length; ) {
            // Set each listing - reverts if the `prices` or `tips` arrays are
            // not equal in length to the `ids` array (indexOOB error)
            _list(ids[i], prices[i], tips[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchList(ids);
    }

    /**
     * @notice Edit a batch of listings
     * @param  ids        uint256[]  Token IDs
     * @param  newPrices  uint48[]   New prices
     */
    function batchEdit(
        uint256[] calldata ids,
        uint48[] calldata newPrices
    ) external {
        for (uint256 i; i < ids.length; ) {
            // Reverts with indexOOB if `newPrices`'s length is not equal to `ids`'s
            _edit(ids[i], newPrices[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchEdit(ids);
    }

    /**
     * @notice Cancel a batch of listings
     * @param  ids  uint256[]  Token IDs
     */
    function batchCancel(uint256[] calldata ids) external {
        for (uint256 i; i < ids.length; ) {
            _cancel(ids[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchCancel(ids);
    }

    /**
     * @notice Fulfill a batch of listings
     * @param  ids  uint256[]  Token IDs
     */
    function batchBuy(uint256[] calldata ids) external payable nonReentrant {
        uint256 id;
        uint256 totalPriceETH;
        uint256 totalSellerProceeds;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            // Increment iterator variable since we are conditionally skipping (i.e. listing does not exist)
            unchecked {
                ++i;
            }

            Listing memory listing = listings[id];

            // Continue to the next id if the listing does not exist (e.g. listing canceled or purchased before this call)
            if (listing.price == 0) continue;

            (
                uint256 priceETH,
                uint256 sellerProceeds
            ) = _calculateListingValues(listing.price, listing.tip);

            // Accrue totalPriceETH, which will be used to determine if sufficient value was sent at the end
            totalPriceETH += priceETH;

            // Since seller proceeds is a subset of totalPriceETH, won't overflow without totalPriceETH doing so and reverting first
            unchecked {
                // Accrue totalSellerProceeds, which will enable us to calculate and transfer the tip in a single call
                totalSellerProceeds += sellerProceeds;
            }

            // Delete listing prior to setting the token to the buyer
            delete listings[id];

            // Set the new token owner to the buyer
            ownerOf[id] = msg.sender;

            // Transfer the sales proceeds to the seller
            payable(listing.seller).safeTransferETH(sellerProceeds);
        }

        // Revert if msg.value does not cover the *total* listing price in ETH
        if (msg.value < totalPriceETH) revert Insufficient();

        // Transfer the cumulative tips (if any) to the tip recipient
        if (msg.value - totalSellerProceeds != 0)
            tipRecipient.safeTransferETH(msg.value - totalSellerProceeds);

        emit BatchBuy(ids);
    }
}
