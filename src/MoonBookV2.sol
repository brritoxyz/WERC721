// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Moon} from "src/Moon.sol";

contract MoonBook is
    Owned,
    ERC20("Redeemable Token", "MOON", 18),
    ERC721TokenReceiver,
    ReentrancyGuard
{
    using SafeTransferLib for ERC20;
    using SafeTransferLib for ERC4626;
    using SafeTransferLib for address payable;
    using FixedPointMathLib for uint96;
    using FixedPointMathLib for uint256;

    struct Listing {
        // NFT seller, receives ETH upon sale
        address seller;
        // Denominated in ETH
        uint96 price;
    }

    // Maximum duration users must wait to redeem the full ETH value of MOON
    uint256 public constant MAX_REDEMPTION_DURATION = 28 days;

    // For calculating the instant redemption amount
    uint256 public constant INSTANT_REDEMPTION_VALUE_BASE = 100;

    // Fees are 1%
    uint128 public constant MOON_FEE_PERCENT = 1;

    // Used for calculating fees
    uint128 public constant MOON_FEE_PERCENT_BASE = 100;

    // NFT collection contract
    ERC721 public immutable collection;

    // ETH staker contract
    ERC20 public staker;

    // Vault contract
    ERC4626 public vault;

    // Instant redemptions enable users to redeem their ETH rebates immediately
    // by giving up a portion of MOON. The default instant redemption value is
    // 75% of the redeemed MOON amount, but may be tweaked in production
    uint256 public instantRedemptionValue = 75;

    // NFT collection listings
    mapping(uint256 id => Listing listing) public collectionListings;

    // NFT collection-wide offers
    mapping(uint256 offer => mapping(address maker => uint256 quantity))
        public collectionOffers;

    mapping(address => mapping(uint256 => uint256)) public pendingRedemptions;

    event SetStaker(address indexed msgSender, ERC20 staker);
    event SetVault(address indexed msgSender, ERC4626 vault);
    event SetInstantRedemptionValue(
        address indexed msgSender,
        uint256 instantRedemptionValue
    );
    event MakeOffer(
        address indexed msgSender,
        uint256 indexed offer,
        uint256 quantity
    );
    event CancelOffer(
        address indexed msgSender,
        uint256 indexed offer,
        uint256 quantity
    );
    event TakeOffer(
        address indexed msgSender,
        uint256 indexed offer,
        address indexed maker,
        uint256 id
    );

    error InvalidAddress();
    error InvalidAmount();
    error InvalidIDs();
    error OnlySeller();
    error OnlyMaker();
    error InvalidRedemption();

    constructor(
        ERC20 _staker,
        ERC4626 _vault,
        ERC721 _collection
    ) Owned(msg.sender) {
        if (address(_staker) == address(0)) revert InvalidAddress();
        if (address(_vault) == address(0)) revert InvalidAddress();
        if (address(_collection) == address(0)) revert InvalidAddress();

        staker = _staker;
        vault = _vault;
        collection = _collection;
    }

    function _mint(address to, uint256 amount) internal override {
        totalSupply += amount;

        unchecked {
            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            balanceOf[to] += amount;
        }
    }

    function _burn(address from, uint256 amount) internal override {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }
    }

    /**
     * @notice Stake ETH
     * @return balance  uint256  ETH balance staked
     * @return assets   uint256  Vault assets deposited
     * @return shares   uint256  Vault shares received
     */
    function _stakeETH()
        private
        returns (uint256 balance, uint256 assets, uint256 shares)
    {
        balance = address(this).balance;

        // Only execute ETH-staking functions if the ETH balance is non-zero
        if (balance != 0) {
            // Stake ETH balance - reverts if msg.value is zero
            payable(address(staker)).safeTransferETH(balance);

            // Fetch staked ETH balance, the amount which will be deposited into the vault
            assets = staker.balanceOf(address(this));

            // Maximize returns with the staking vault - the Moon contract receives shares
            shares = vault.deposit(assets, address(this));
        }
    }

    /**
     * @notice Instantly redeem MOON for the underlying assets at partial value
     * @param  amount    uint256  MOON amount
     * @return redeemed  uint256  Redeemed MOON
     * @return shares    uint256  Redeemed vault shares
     */
    function _instantRedemption(
        uint256 amount
    ) private returns (uint256 redeemed, uint256 shares) {
        // NOTE: Due to rounding, the redeemed amount will be zero if `amount` is too small
        // The remainder of the function logic assumes that the caller is a logical actor
        // since redeeming extremely small amounts of MOON is uneconomical due to gas fees
        redeemed = amount.mulDivDown(
            instantRedemptionValue,
            INSTANT_REDEMPTION_VALUE_BASE
        );

        // Stake ETH first to ensure that the contract's vault share balance is current
        _stakeETH();

        // Calculate the amount of vault shares redeemed - based on the proportion of
        // the redeemed MOON amount to the total MOON supply
        shares = vault.balanceOf(address(this)).mulDivDown(
            redeemed,
            totalSupply
        );

        // Burn MOON from msg.sender - reverts if their balance is insufficient
        _burn(msg.sender, amount);

        // Mint MOON for the owner, equal to the unredeemed amount
        _mint(owner, amount - redeemed);

        // Transfer the redeemed amount to msg.sender (vault shares, as good as ETH)
        vault.safeTransfer(msg.sender, shares);
    }

    /**
     * @notice Set staker
     * @param  _staker  ERC20  Staker contract
     */
    function setStaker(ERC20 _staker) external onlyOwner {
        if (address(_staker) == address(0)) revert InvalidAddress();

        address vaultAddr = address(vault);

        // Set the vault's allowance to zero for the previous staker
        staker.safeApprove(vaultAddr, 0);

        // Set the new staker
        staker = _staker;

        // Set the vault's allowance to the maximum for the current staker
        _staker.safeApprove(vaultAddr, type(uint256).max);

        emit SetStaker(msg.sender, _staker);
    }

    /**
     * @notice Set the instant redemption value
     * @param  _vault  ERC4626  Vault contract
     */
    function setVault(ERC4626 _vault) external onlyOwner {
        if (address(_vault) == address(0)) revert InvalidAddress();

        // Set the previous vault's allowance to zero
        staker.safeApprove(address(vault), 0);

        // Set the new vault
        vault = _vault;

        // Set the new vault's allowance to the maximum
        staker.safeApprove(address(_vault), type(uint256).max);

        emit SetVault(msg.sender, _vault);
    }

    /**
     * @notice Set the instant redemption value
     * @param  _instantRedemptionValue  uint256  Instant redemption value
     */
    function setInstantRedemptionValue(
        uint256 _instantRedemptionValue
    ) external onlyOwner {
        if (_instantRedemptionValue > INSTANT_REDEMPTION_VALUE_BASE)
            revert InvalidAmount();

        // Set the new instantRedemptionValue
        instantRedemptionValue = _instantRedemptionValue;

        emit SetInstantRedemptionValue(msg.sender, _instantRedemptionValue);
    }

    /**
     * @notice Stake ETH
     * @return uint256  ETH balance staked
     * @return uint256  Vault assets deposited
     * @return uint256  Vault shares received
     */
    function stakeETH()
        external
        nonReentrant
        returns (uint256, uint256, uint256)
    {
        return _stakeETH();
    }

    /**
     * @notice Begin a MOON redemption
     * @param  amount    uint256  MOON amount
     * @param  duration  uint256  Queue duration in seconds
     * @return redeemed  uint256  Redeemed MOON
     * @return shares    uint256  Redeemed vault shares
     */
    function initiateRedemption(
        uint256 amount,
        uint256 duration
    ) external nonReentrant returns (uint256 redeemed, uint256 shares) {
        if (amount == 0) revert InvalidAmount();
        if (duration > MAX_REDEMPTION_DURATION) revert InvalidAmount();

        // Perform an instant redemption if the duration is zero
        if (duration == 0) {
            return _instantRedemption(amount);
        }

        // The redeemed amount is based on the total duration the user is willing
        // to wait for their redemption to complete (waiting the max duration
        // results in 100% of the underlying ETH-based assets being redeemed)
        redeemed = amount.mulDivDown(duration, MAX_REDEMPTION_DURATION);

        // Stake ETH first to ensure that the contract's vault share balance is current
        _stakeETH();

        // Calculate the amount of vault shares redeemed - based on the proportion of
        // the redeemed MOON amount to the total MOON supply
        shares = vault.balanceOf(address(this)).mulDivDown(
            redeemed,
            totalSupply
        );

        // Burn MOON from msg.sender - reverts if their balance is insufficient
        _burn(msg.sender, amount);

        // If amount does not equal redeemed, then `duration` is less than the maximum
        if (duration != MAX_REDEMPTION_DURATION) {
            _mint(owner, amount - redeemed);
        }

        // Set the amount of shares that the user can claim after the duration has elapsed
        pendingRedemptions[msg.sender][block.timestamp + duration] += shares;
    }

    /**
     * @notice Fulfill a MOON redemption
     * @param  redemptionTimestamp  uint256  MOON amount
     * @return shares               uint256  Redeemed vault shares
     */
    function fulfillRedemption(
        uint256 redemptionTimestamp
    ) external nonReentrant returns (uint256 shares) {
        // If the redemption timestamp is before the current time, then it's too early - revert
        if (redemptionTimestamp < block.timestamp) revert InvalidRedemption();

        shares = pendingRedemptions[msg.sender][redemptionTimestamp];

        // If the redeemable amount is zero then the redemption was already claimed or non-existent
        if (shares == 0) revert InvalidRedemption();

        // Zero out the pending redemption amount prior to transferring shares
        pendingRedemptions[msg.sender][redemptionTimestamp] = 0;

        // Stake ETH to ensure there are sufficient shares to fulfill the redemption
        _stakeETH();

        vault.safeTransfer(msg.sender, shares);
    }

    /**
     * @notice List a NFT for sale
     * @param  id     uint256  NFT ID
     * @param  price  uint96   NFT price in ETH
     */
    function list(uint256 id, uint96 price) external nonReentrant {
        // Reverts if the NFT is not owned by msg.sender
        collection.safeTransferFrom(msg.sender, address(this), id);

        // Set listing details
        collectionListings[id] = Listing(msg.sender, price);
    }

    /**
     * @notice List many NFTs for sale
     * @param  ids     uint256[]  NFT IDs
     * @param  prices  uint96[]   NFT prices in ETH
     */
    function listMany(
        uint256[] calldata ids,
        uint96[] calldata prices
    ) external nonReentrant {
        uint256 iLen = ids.length;

        // Loop body does not execute if iLen is zero, and tx reverts if the
        // `ids` and `prices` arrays are mismatched in terms of length
        for (uint256 i; i < iLen; ) {
            uint256 id = ids[i];

            // Reverts if the NFT is not owned by msg.sender
            collection.safeTransferFrom(msg.sender, address(this), id);

            // Set listing details
            collectionListings[id] = Listing(msg.sender, prices[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Edit NFT listing price
     * @param  id        uint256  NFT ID
     * @param  newPrice  uint96   New NFT price
     */
    function editListing(uint256 id, uint96 newPrice) external {
        Listing storage listing = collectionListings[id];

        // msg.sender must be the listing seller, otherwise they cannot edit
        if (listing.seller != msg.sender) revert OnlySeller();

        listing.price = newPrice;
    }

    /**
     * @notice Cancel NFT listing and reclaim NFT
     * @param  id  uint256  NFT ID
     */
    function cancelListing(uint256 id) external nonReentrant {
        // msg.sender must be the listing seller, otherwise they cannot cancel
        if (collectionListings[id].seller != msg.sender) revert OnlySeller();

        delete collectionListings[id];

        // Return the NFT to the seller
        collection.safeTransferFrom(address(this), msg.sender, id);
    }

    /**
     * @notice Buy a NFT
     * @param  id  uint256  NFT ID
     */
    function buy(uint256 id) external payable nonReentrant {
        Listing memory listing = collectionListings[id];

        // Reverts if msg.value does not equal listing price
        if (msg.value != listing.price) revert InvalidAmount();

        // Delete listing before exchanging tokens
        delete collectionListings[id];

        // Send NFT to the buyer after confirming sufficient ETH was sent
        // Reverts if invalid listing (i.e. contract no longer has the NFT)
        collection.safeTransferFrom(address(this), msg.sender, id);

        // Calculate protocol fees
        uint256 fees = listing.price.mulDivDown(
            MOON_FEE_PERCENT,
            MOON_FEE_PERCENT_BASE
        );

        // Transfer the post-fee sale proceeds to the seller
        payable(listing.seller).safeTransferETH(listing.price - fees);

        // If there are fees, deposit them into the protocol contract, and distribute
        // MOON rewards to the seller (equal to the ETH fees they've paid)
        if (fees != 0) _mint(listing.seller, fees);
    }

    /**
     * @notice Make offers
     * @param  offer     uint256  Offer amount in ETH
     * @param  quantity  uint256  Offer quantity (i.e. number of NFTs)
     */
    function makeOffer(uint256 offer, uint256 quantity) external payable {
        if (offer == 0) revert InvalidAmount();
        if (quantity == 0) revert InvalidAmount();

        // Revert if the maker did not send enough ETH to cover their offer
        if (msg.value != offer * quantity) revert InvalidAmount();

        // User offer is the amount of ETH sent with the transaction
        collectionOffers[offer][msg.sender] += quantity;

        emit MakeOffer(msg.sender, offer, quantity);
    }

    /**
     * @notice Cancel offers
     * @param  offer     uint256  Offer amount in ETH
     * @param  quantity  uint256  Offer quantity (i.e. number of NFTs)
     */
    function cancelOffer(
        uint256 offer,
        uint256 quantity
    ) external nonReentrant {
        if (offer == 0) revert InvalidAmount();
        if (quantity == 0) revert InvalidAmount();

        // User offer is the amount of ETH sent with the transaction
        // Reverts if the quantity is greater than what's deposited
        collectionOffers[offer][msg.sender] -= quantity;

        payable(msg.sender).safeTransferETH(offer * quantity);

        emit CancelOffer(msg.sender, offer, quantity);
    }

    /**
     * @notice Take offer
     * @param  offer  uint256  Offer amount in ETH
     * @param  maker  address  Offer maker
     * @param  id     uint256  NFT ID
     */
    function takeOffer(
        uint256 offer,
        address maker,
        uint256 id
    ) external nonReentrant {
        if (offer == 0) revert InvalidAmount();
        if (maker == address(0)) revert InvalidAddress();

        // Decrement the maker's offer quantity to reflect taken offer
        // Reverts if the offer maker does not have enough deposited
        --collectionOffers[offer][maker];

        // Transfer the NFT from the offer taker (msg.sender) to the maker
        // Reverts if msg.sender does not have the NFT at the specified ID
        collection.safeTransferFrom(msg.sender, maker, id);

        // Calculate protocol fees
        uint256 fees = offer.mulDivDown(
            MOON_FEE_PERCENT,
            MOON_FEE_PERCENT_BASE
        );

        // Transfer the post-fee sale proceeds to the seller
        payable(msg.sender).safeTransferETH(offer - fees);

        // If there are fees, deposit them into the protocol contract, and distribute
        // MOON rewards to the seller (equal to the ETH fees they've paid)
        if (fees != 0) _mint(msg.sender, fees);

        emit TakeOffer(msg.sender, offer, maker, id);
    }
}
