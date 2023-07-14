// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ReentrancyGuard} from "src/lib/ReentrancyGuard.sol";

abstract contract Page is ERC721TokenReceiver, ReentrancyGuard {
    using SafeTransferLib for address payable;

    struct Listing {
        // Seller address
        address payable seller;
        // Adequate for 79m ether
        uint96 price;
    }

    bool private _initialized;

    // Tracks the owner of each ERC721 derivative
    mapping(uint256 => address) public ownerOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => Listing) public listings;
    mapping(address => mapping(uint256 => uint256)) public offers;

    event Initialize();
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event BatchTransfer(address indexed from, address[] to, uint256[] ids);
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event Deposit(address indexed depositor, uint256 indexed id);
    event Withdraw(address indexed withdrawer, uint256 indexed id);
    event List(address indexed seller, uint256 indexed id, uint96 price);
    event Edit(address indexed seller, uint256 indexed id, uint96 price);
    event Cancel(address indexed seller, uint256 indexed id);
    event BatchDeposit(address indexed depositor, uint256[] ids);
    event BatchWithdraw(address indexed withdrawer, uint256[] ids);
    event BatchList(address indexed seller, uint256[] ids, uint96[] prices);
    event BatchEdit(address indexed seller, uint256[] ids, uint96[] prices);
    event BatchCancel(address indexed seller, uint256[] ids);
    event Buy(address indexed buyer, uint256 indexed id);
    event BatchBuy(address indexed buyer, uint256[] ids);
    event MakeOffer(address indexed maker, uint256 offer, uint256 quantity);
    event CancelOffer(address indexed maker, uint256 offer, uint256 quantity);
    event TakeOffer(
        address indexed taker,
        uint256[] ids,
        address indexed maker,
        uint256 offer
    );

    error AlreadyInitialized();
    error NotOwner();
    error NotSeller();
    error NotListed();
    error NotApproved();
    error InvalidPrice();
    error InvalidOffer();
    error InsufficientMsgValue();
    error UnsafeRecipient();

    constructor() payable {
        // Prevent the implementation from being initialized
        _initialized = true;
    }

    modifier onlyUninitialized() {
        if (_initialized) revert AlreadyInitialized();
        _;
    }

    /**
     * @notice Initializes the minimal proxy contract storage
     */
    function initialize() external onlyUninitialized {
        // Prevent initialize from being called again
        _initialized = true;

        // Initialize `locked` with the value of 1 (i.e. unlocked)
        locked = 1;

        emit Initialize();
    }

    /**
     * @notice Returns the ERC-721 contract (underlying asset)
     * @return ERC721  ERC-721 contract associated with this Page
     */
    function collection() public view virtual returns (ERC721);

    /**
     * @notice Returns the result of calling `name` on the ERC-721 contract
     * @return string  ERC-721 contract `name` return value
     */
    function name() external view returns (string memory) {
        return collection().name();
    }

    /**
     * @notice Returns the result of calling `symbol` on the ERC-721 contract
     * @return string  ERC-721 contract `synbol` return value
     */
    function symbol() external view returns (string memory) {
        return collection().symbol();
    }

    /**
     * @notice Returns the result of calling `tokenURI` on the ERC-721 contract
     * @return string  ERC-721 contract `tokenURI` return value
     */
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        return collection().tokenURI(_tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transfer(address to, uint256 id) external {
        // Revert if `msg.sender` is not the token owner
        if (msg.sender != ownerOf[id]) revert NotOwner();

        // Revert if `to` is the zero address
        if (to == address(0)) revert UnsafeRecipient();

        // Set new owner as `to`
        ownerOf[id] = to;

        emit Transfer(msg.sender, to, id);
    }

    function batchTransfer(
        address[] calldata to,
        uint256[] calldata ids
    ) external {
        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            id = ids[i];

            // Revert if `msg.sender` is not the token owner
            if (msg.sender != ownerOf[id]) revert NotOwner();

            // Revert if `to` is the zero address
            if (to[i] == address(0)) revert UnsafeRecipient();

            // Set new owner as `to`
            ownerOf[id] = to[i];

            unchecked {
                ++i;
            }
        }

        emit BatchTransfer(msg.sender, to, ids);
    }

    function transferFrom(address from, address to, uint256 id) external {
        // Revert if `from` is not the token owner
        if (from != ownerOf[id]) revert NotOwner();

        // Revert if `to` is the zero address
        if (to == address(0)) revert UnsafeRecipient();

        // Revert if `msg.sender` is not `from` and does not have transfer approval
        if (msg.sender != from && !isApprovedForAll[from][msg.sender])
            revert NotApproved();

        // Set new owner as `to`
        ownerOf[id] = to;

        emit Transfer(from, to, id);
    }

    function batchTransferFrom(
        address from,
        address[] calldata to,
        uint256[] calldata ids
    ) external {
        // Revert if `msg.sender` is not `from` and does not have transfer approval
        if (msg.sender != from && !isApprovedForAll[from][msg.sender])
            revert NotApproved();

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            id = ids[i];

            // Revert if `from` is not the token owner
            if (from != ownerOf[id]) revert NotOwner();

            // Revert if `to` is the zero address
            if (to[i] == address(0)) revert UnsafeRecipient();

            ownerOf[id] = to[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit BatchTransfer(from, to, ids);
    }

    /**
     * @notice Deposit a NFT into the vault and mint a redeemable derivative token
     * @param  id  uint256  Token ID
     */
    function _deposit(uint256 id) private {
        // Mint the derivative token for the specified recipient (same ID)
        ownerOf[id] = msg.sender;

        // Transfer the NFT to self before minting the derivative token
        // Reverts if unapproved or if msg.sender does not have the token
        collection().transferFrom(msg.sender, address(this), id);
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id  uint256  Token ID
     */
    function _withdraw(uint256 id) private {
        // Revert if msg.sender is not the owner of the derivative token
        if (ownerOf[id] != msg.sender) revert NotOwner();

        // Burn the derivative token before transferring the NFT to the recipient
        delete ownerOf[id];

        // Transfer the NFT to the recipient - reverts if recipient is zero address
        collection().safeTransferFrom(address(this), msg.sender, id);
    }

    /**
     * @notice Create a listing
     * @param  id     uint256  Token ID
     * @param  price  uint96   Price
     */
    function _list(uint256 id, uint96 price) private {
        // Reverts if msg.sender does not have the token
        if (ownerOf[id] != msg.sender) revert NotOwner();

        // Revert if the price is zero
        if (price == 0) revert InvalidPrice();

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
        if (newPrice == 0) revert InvalidPrice();

        Listing storage listing = listings[id];

        // Reverts if msg.sender is not the seller or listing does not exist
        if (listing.seller != msg.sender) revert NotSeller();

        listing.price = newPrice;
    }

    /**
     * @notice Cancel a listing
     * @param  id  uint256  Token ID
     */
    function _cancel(uint256 id) private {
        // Reverts if msg.sender is not the seller
        if (listings[id].seller != msg.sender) revert NotSeller();

        // Delete listing prior to returning the token
        delete listings[id];

        ownerOf[id] = msg.sender;
    }

    /**
     * @notice Deposit a NFT into the vault to mint a redeemable derivative token with the same ID
     * @param  id  uint256  Token ID
     */
    function deposit(uint256 id) external {
        _deposit(id);

        emit Deposit(msg.sender, id);
    }

    /**
     * @notice Withdraw a NFT from the vault by redeeming a derivative token
     * @param  id  uint256  Token ID
     */
    function withdraw(uint256 id) external {
        _withdraw(id);

        emit Withdraw(msg.sender, id);
    }

    /**
     * @notice Create a listing
     * @param  id     uint256  Token ID
     * @param  price  uint96   Price
     */
    function list(uint256 id, uint96 price) external {
        _list(id, price);

        emit List(msg.sender, id, price);
    }

    /**
     * @notice Edit a listing
     * @param  id        uint256  Token ID
     * @param  newPrice  uint96   New price
     */
    function edit(uint256 id, uint96 newPrice) external {
        _edit(id, newPrice);

        emit Edit(msg.sender, id, newPrice);
    }

    /**
     * @notice Cancel a listing
     * @param  id  uint256  Token ID
     */
    function cancel(uint256 id) external {
        _cancel(id);

        emit Cancel(msg.sender, id);
    }

    /**
     * @notice Batch deposit
     * @param  ids  uint256[]  Token IDs
     */
    function batchDeposit(uint256[] calldata ids) external nonReentrant {
        uint256 idsLength = ids.length;

        // If ids.length is zero then the loop body never runs and caller wastes gas
        for (uint256 i = 0; i < idsLength; ) {
            _deposit(ids[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchDeposit(msg.sender, ids);
    }

    /**
     * @notice Batch withdraw
     * @param  ids  uint256[]  Token IDs
     */
    function batchWithdraw(uint256[] calldata ids) external nonReentrant {
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            _withdraw(ids[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchWithdraw(msg.sender, ids);
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
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            // Set each listing - reverts if the `prices` or `tips` arrays are
            // not equal in length to the `ids` array (indexOOB error)
            _list(ids[i], prices[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchList(msg.sender, ids, prices);
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
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            // Reverts with indexOOB if `newPrices`'s length is not equal to `ids`'s
            _edit(ids[i], newPrices[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchEdit(msg.sender, ids, newPrices);
    }

    /**
     * @notice Cancel a batch of listings
     * @param  ids  uint256[]  Token IDs
     */
    function batchCancel(uint256[] calldata ids) external {
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ) {
            _cancel(ids[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchCancel(msg.sender, ids);
    }

    /**
     * @notice Fulfill a listing
     * @param  id  uint256  Token ID
     */
    function buy(uint256 id) external payable {
        Listing memory listing = listings[id];

        // Revert if the listing does not exist (price cannot be zero)
        if (listing.price == 0) revert NotListed();

        // Reverts if the msg.value does not cover the listing price
        if (msg.value != listing.price) revert InsufficientMsgValue();

        // Delete listing prior to setting the token to the buyer
        delete listings[id];

        // Set the new token owner to the buyer
        ownerOf[id] = msg.sender;

        // Transfer the sales proceeds to the seller
        listing.seller.safeTransferETH(msg.value);

        emit Buy(msg.sender, id);
    }

    /**
     * @notice Fulfill a batch of listings
     * @param  ids  uint256[]  Token IDs
     */
    function batchBuy(uint256[] calldata ids) external payable nonReentrant {
        uint256 id;
        uint256 idsLength = ids.length;

        // Used for checking that msg.value is enough to cover the purchase price - buyer must send GTE the total ETH of all listings
        // Any leftover ETH is returned at the end *after* the listing sale prices have been deducted from `availableETH`
        uint256 availableETH = msg.value;

        for (uint256 i = 0; i < idsLength; ) {
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

        emit BatchBuy(msg.sender, ids);
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
        if (msg.value != offer * quantity) revert InsufficientMsgValue();

        // Increase offer quantity
        // Cannot realistically overflow due to the msg.value check above
        // Even if it did overflow, the maker would be the one harmed (i.e.
        // ETH sent more than the offer quantity reflected in the contract),
        // making this an unlikely attack vector
        unchecked {
            offers[msg.sender][offer] += quantity;
        }

        emit MakeOffer(msg.sender, offer, quantity);
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

        emit CancelOffer(msg.sender, offer, quantity);
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
        // is the zero address, or if the offer is zero with arithmetic underflow err
        // If `ids.length` is 0, then the offer quantity will be deducted by zero, the
        // loop will not execute, and zero ETH will be sent to the taker, resulting in
        // the caller wasting gas and making this an infeasible attack vector
        uint256 idsLength = ids.length;
        offers[maker][offer] -= idsLength;

        uint256 id;

        for (uint256 i = 0; i < idsLength; ) {
            id = ids[i];

            // Revert if msg.sender/taker is not the owner of the derivative token
            if (ownerOf[id] != msg.sender) revert NotOwner();

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
            payable(msg.sender).safeTransferETH(offer * idsLength);
        }

        emit TakeOffer(msg.sender, ids, maker, offer);
    }
}
