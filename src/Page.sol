// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "src/base/ReentrancyGuard.sol";
import {PageToken} from "src/PageToken.sol";

contract Page is
    Initializable,
    ReentrancyGuard,
    ERC721TokenReceiver,
    PageToken
{
    using SafeTransferLib for address payable;

    struct Listing {
        // Seller address
        address seller;
        // Adequate for 2.8m ether since the denomination is 0.00000001 ETH (1e10)
        uint48 price;
        // Optional tip amount - deducted from the sales proceeds
        uint48 tip;
    }

    // Price and tips are denominated in 0.00000001 ETH (i.e. 1e10)
    uint256 public constant VALUE_DENOM = 0.00000001 ether;

    ERC721 public collection;

    address payable public tipRecipient;

    mapping(uint256 => Listing) public listings;

    mapping(address => mapping(uint256 => uint256)) public offers;

    event Initialize(ERC721 collection, address tipRecipient);
    event SetTipRecipient(address tipRecipient);
    event List(uint256 id);
    event Edit(uint256 id);
    event Cancel(uint256 id);
    event Buy(uint256 id);
    event BatchList(uint256[] ids);
    event BatchEdit(uint256[] ids);
    event BatchCancel(uint256[] ids);
    event BatchBuy(uint256[] ids);
    event MakeOffer(address maker);
    event CancelOffer(address maker);
    event TakeOffer(address taker);

    error Zero();
    error Invalid();
    error Unauthorized();
    error Nonexistent();
    error Insufficient();

    constructor() payable {
        // Disable initialization on the implementation contract
        _disableInitializers();
    }

    /**
     * @notice Initializes the minimal proxy
     * @param  _collection    ERC721   Collection contract
     * @param  _tipRecipient  address  Tip recipient
     */
    function initialize(
        ERC721 _collection,
        address payable _tipRecipient
    ) external initializer {
        // Initialize ReentrancyGuard by setting `locked` to unlocked (i.e. 1)
        locked = 1;

        // Initialize this contract with the ERC721 collection contract
        collection = _collection;

        // Initialize this contract with a tip recipient
        tipRecipient = _tipRecipient;

        emit Initialize(_collection, _tipRecipient);
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
        // Knowing that, we can be sure that the below will never overflow since (2**48 - 1) * 1e10 < (2**256 - 1)
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
     * @notice Retrieves the collection name
     * @return string  Token name
     */
    function name() external view override returns (string memory) {
        return collection.name();
    }

    /**
     * @notice Retrieves the collection symbol
     * @return string  Token symbol
     */
    function symbol() external view override returns (string memory) {
        return collection.symbol();
    }

    /**
     * @notice Retrieves the collection token URI for the specified ID
     * @param  _tokenId  uint256  Token ID
     * @return           string   JSON file that conforms to the ERC721 Metadata JSON Schema
     */
    function tokenURI(
        uint256 _tokenId
    ) external view override returns (string memory) {
        return collection.tokenURI(_tokenId);
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
    function cancel(uint256 id) external payable {
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
        // Cannot overflow since msg.value will always be GTE sellerProceeds
        // See msg.value < priceETH check above
        unchecked {
            if (msg.value - sellerProceeds != 0)
                tipRecipient.safeTransferETH(msg.value - sellerProceeds);
        }

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
        // Cannot overflow since msg.value will always be GTE totalSellerProceeds
        // See msg.value < totalPriceETH check above
        unchecked {
            if (msg.value - totalSellerProceeds != 0)
                tipRecipient.safeTransferETH(msg.value - totalSellerProceeds);
        }

        emit BatchBuy(ids);
    }

    /**
     * @notice Make/increase a global offer
     * @param  offer     uint256  Offer in ETH
     * @param  quantity  uint256  Offer quantity to make
     */
    function makeOffer(uint256 offer, uint256 quantity) external payable {
        // Reverts if msg.value does not equal the necessary amount
        // If msg.value, and offer and/or quantity are zero then the caller
        // wastes gas since their offer value will be zero (no one will take
        // the offer) or their quantity will not increase. Since this is the
        // assumption, we do not need to validate offer and quantity.
        if (msg.value != offer * quantity) revert Invalid();

        // Increase offer quantity
        // Cannot realistically overflow due to the msg.value check above
        // Even if it did overflow, the maker would be the one harmed (i.e.
        // ETH sent more than the offer quantity reflected in the contract),
        // making this an unlikely attack vector
        unchecked {
            offers[msg.sender][offer] += quantity;
        }

        emit MakeOffer(msg.sender);
    }

    /**
     * @notice Cancel/reduce a global offer
     * @param  offer     uint256  Offer in ETH
     * @param  quantity  uint256  Offer quantity to cancel
     */
    function cancelOffer(
        uint256 offer,
        uint256 quantity
    ) external nonReentrant {
        // Deduct quantity from the user's offers - reverts if `quantity`
        // exceeds the actual amount of offers that the user has made
        // If offer and/or quantity are zero then the amount of ETH returned
        // will be zero (if no arithmetic underflow), resulting in gas wasted
        // (making this an unlikely attack vector)
        offers[msg.sender][offer] -= quantity;

        // Cannot realistically overflow if the above does not underflow
        // The reason being that the amount returned to the maker/msg.sender
        // is always less than or equal to the amount they've deposited
        unchecked {
            // Transfer the offer value back to the user
            payable(msg.sender).safeTransferETH(offer * quantity);
        }

        emit CancelOffer(msg.sender);
    }

    /**
     * @notice Take global offers
     * @param  ids    uint256[]  Token IDs exchanged between taker and maker
     * @param  maker  address    Maker address
     * @param  offer  uint256    Offer in ETH
     */
    function takeOffer(
        uint256[] calldata ids,
        address maker,
        uint256 offer
    ) external payable nonReentrant {
        // Reduce maker's offer quantity by the taken amount (i.e. token quantity)
        // Reverts if the taker quantity exceeds the maker offer quantity, if the maker
        // is the zero address, or if the offer is zero (arithmetic underflow)
        // If `ids.length` is zero offer quantity will be deducted, but zero ETH will
        // also be sent to the taker, resulting in the caller wasting gas and making
        // this an unlikely attack vector
        offers[maker][offer] -= ids.length;

        uint256 id;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            // Revert if msg.sender/taker is not the owner of the derivative token
            if (ownerOf[id] != msg.sender) revert Unauthorized();

            // Set maker as the new owner of the token
            ownerOf[id] = maker;

            unchecked {
                ++i;
            }
        }

        // Will not overflow since the check above verifies that there was a
        // sufficient offer quantity (and ETH) to cover the transfer
        unchecked {
            // Send maker's funds to the offer taker
            payable(msg.sender).safeTransferETH(offer * ids.length);
        }

        // If the offer taker sent a tip, transfer it to the tip recipient
        if (msg.value != 0) tipRecipient.safeTransferETH(msg.value);

        emit TakeOffer(msg.sender);
    }
}
