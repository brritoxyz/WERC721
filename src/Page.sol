// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clone} from "solady/utils/Clone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {PageToken} from "src/PageToken.sol";

interface IERC721 {
    function transferFrom(address from, address to, uint256 id) external;

    function safeTransferFrom(address from, address to, uint256 id) external;

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 id) external view returns (string memory);
}

contract Page is Clone, PageToken {
    using SafeTransferLib for address payable;

    struct Listing {
        // Seller address
        address payable seller;
        // Adequate for 79m ether
        uint96 price;
    }

    bool private _initialized;

    uint256 private _locked;

    mapping(uint256 => Listing) public listings;

    mapping(address => mapping(uint256 => uint256)) public offers;

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

    error Invalid();
    error Unauthorized();
    error Insufficient();
    error MulticallError(uint256 callIndex);

    constructor() payable {
        // Prevent the implementation from being initialized
        _initialized = true;
    }

    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");

        _locked = 2;

        _;

        _locked = 1;
    }

    /**
     * @notice Initializes the minimal proxy contract storage
     */
    function initialize() external {
        if (_initialized) revert();

        // Prevent initialize from being called again
        _initialized = true;

        // Initialize `locked` with the value of 1 (i.e. unlocked)
        _locked = 1;
    }

    /**
     * @notice Deposit a NFT into the vault to mint a redeemable derivative token with the same ID
     * @param  id         uint256  Token ID
     * @param  recipient  address  Derivative token recipient
     */
    function _deposit(uint256 id, address recipient) private {
        // Mint the derivative token for the specified recipient (same ID)
        ownerOf[id] = recipient;

        // Transfer the NFT to self before minting the derivative token
        // Reverts if unapproved or if msg.sender does not have the token
        IERC721(_getArgAddress(0)).transferFrom(msg.sender, address(this), id);
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
        delete ownerOf[id];

        // Transfer the NFT to the recipient - reverts if recipient is zero address
        IERC721(_getArgAddress(0)).safeTransferFrom(
            address(this),
            recipient,
            id
        );
    }

    /**
     * @notice Create a listing
     * @param  id     uint256  Token ID
     * @param  price  uint96   Price
     */
    function _list(uint256 id, uint96 price) private {
        // Reverts if msg.sender does not have the token
        if (ownerOf[id] != msg.sender) revert Unauthorized();

        // Revert if the price is zero
        if (price == 0) revert Invalid();

        // Update token owner to this contract to prevent double-listing
        ownerOf[id] = address(this);

        // Set the listing
        listings[id] = Listing(payable(msg.sender), price);
    }

    /**
     * @notice Edit a listing
     * @param  id        uint256  Token ID
     * @param  newPrice  uint96   New price
     */
    function _edit(uint256 id, uint96 newPrice) private {
        // Revert if the new price is zero
        if (newPrice == 0) revert Invalid();

        Listing storage listing = listings[id];

        // Reverts if msg.sender is not the seller or listing does not exist
        if (listing.seller != msg.sender) revert Unauthorized();

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

    function collection() external pure returns (address) {
        return _getArgAddress(0);
    }

    /**
     * @notice Retrieves the collection name
     * @return string  Token name
     */
    function name() external view override returns (string memory) {
        return IERC721(_getArgAddress(0)).name();
    }

    /**
     * @notice Retrieves the collection symbol
     * @return string  Token symbol
     */
    function symbol() external view override returns (string memory) {
        return IERC721(_getArgAddress(0)).symbol();
    }

    /**
     * @notice Retrieves the collection token URI for the specified ID
     * @param  tokenId  uint256  Token ID
     * @return           string   JSON file that conforms to the ERC721 Metadata JSON Schema
     */
    function tokenURI(
        uint256 tokenId
    ) external view override returns (string memory) {
        return IERC721(_getArgAddress(0)).tokenURI(tokenId);
    }

    /**
     * @notice Deposit a NFT into the vault to mint a redeemable derivative token with the same ID
     * @param  id         uint256  Token ID
     * @param  recipient  address  Derivative token recipient
     */
    function deposit(uint256 id, address recipient) external {
        _deposit(id, recipient);
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id         uint256  Token ID
     * @param  recipient  address  NFT recipient
     */
    function withdraw(uint256 id, address recipient) external {
        _withdraw(id, recipient);
    }

    /**
     * @notice Create a listing
     * @param  id     uint256  Token ID
     * @param  price  uint96   Price
     */
    function list(uint256 id, uint96 price) external {
        _list(id, price);

        emit List(id);
    }

    /**
     * @notice Edit a listing
     * @param  id        uint256  Token ID
     * @param  newPrice  uint96   New price
     */
    function edit(uint256 id, uint96 newPrice) external {
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
    function buy(uint256 id) external payable {
        Listing memory listing = listings[id];

        // Revert if the listing does not exist (price cannot be zero)
        if (listing.price == 0) revert Invalid();

        // Reverts if the msg.value does not cover the listing price
        if (msg.value != listing.price) revert Insufficient();

        // Delete listing prior to setting the token to the buyer
        delete listings[id];

        // Set the new token owner to the buyer
        ownerOf[id] = msg.sender;

        // Transfer the sales proceeds to the seller
        listing.seller.safeTransferETH(msg.value);

        emit Buy(id);
    }

    /**
     * @notice Batch deposit
     * @param  ids        uint256[]  Token IDs
     * @param  recipient  address    Derivative token recipient
     */
    function batchDeposit(uint256[] calldata ids, address recipient) external {
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
    function batchWithdraw(uint256[] calldata ids, address recipient) external {
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
     * @param  prices  uint96[]   Prices
     */
    function batchList(
        uint256[] calldata ids,
        uint96[] calldata prices
    ) external {
        for (uint256 i; i < ids.length; ) {
            // Set each listing - reverts if the `prices` or `tips` arrays are
            // not equal in length to the `ids` array (indexOOB error)
            _list(ids[i], prices[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchList(ids);
    }

    /**
     * @notice Edit a batch of listings
     * @param  ids        uint256[]  Token IDs
     * @param  newPrices  uint96[]   New prices
     */
    function batchEdit(
        uint256[] calldata ids,
        uint96[] calldata newPrices
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

        // Used for checking that msg.value is enough to cover the purchase price - buyer must send GTE the total ETH of all listings
        // Any leftover ETH is returned at the end *after* the listing sale prices have been deducted from `availableETH`
        uint256 availableETH = msg.value;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];

            // Increment iterator variable since we are conditionally skipping (i.e. listing does not exist)
            unchecked {
                ++i;
            }

            Listing memory listing = listings[id];

            // Continue to the next id if the listing does not exist (e.g. listing canceled or purchased before this call executes)
            if (listing.price == 0) continue;

            // Deduct the listing price from the available ETH sent by the buyer (reverts with arithmetic underflow if insufficient)
            availableETH -= listing.price;

            // Delete listing prior to setting the token to the buyer
            delete listings[id];

            // Set the new token owner to the buyer
            ownerOf[id] = msg.sender;

            // Transfer the sales proceeds to the seller - reverts if the contract does not have enough ETH due to msg.value
            // not being sufficient to cover the purchase. If the contract does have enough ETH - due to offer makers depositing
            // ETH (even if the caller did not include a sufficient amount) - then the post-loop check will revert
            listing.seller.safeTransferETH(listing.price);
        }

        // If there is available ETH remaining after the purchases (i.e. too much ETH was sent), return it to the buyer
        if (availableETH != 0) {
            payable(msg.sender).safeTransferETH(availableETH);
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
    function cancelOffer(uint256 offer, uint256 quantity) external {
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
    ) external {
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

        emit TakeOffer(msg.sender);
    }

    /**
     * @notice Receives and executes a batch of function calls on this contract
     * @notice Non-payable to avoid reuse of msg.value across calls (thank you Solady)
     * @notice See: https://www.paradigm.xyz/2021/08/two-rights-might-make-a-wrong
     * @param  data       bytes[]  Encoded function selectors with optional data
     */
    function multicall(
        bytes[] calldata data
    ) external returns (bytes[] memory results) {
        results = new bytes[](data.length);

        for (uint256 i; i < data.length; ) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );

            if (!success) revert MulticallError(i);

            results[i] = result;

            unchecked {
                ++i;
            }
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
