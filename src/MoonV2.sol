// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract Moon is
    ERC20("Moonbase Reward Token", "MOON", 18),
    Owned,
    ReentrancyGuard
{
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address payable;

    // Fixed parameters for calculating user MOON reward amounts
    uint128 public constant USER_SHARE_BASE = 100;

    // Used for calculating the mintable MOON amounts for users (fixed at 90%)
    uint128 public constant USER_SHARE = 90;

    // Factories deploy MoonBook contracts and enable them to mint MOON rewards
    // When factories are upgraded, they are set as the new factory
    // Old factories will no longer be able to call `addMinter`, effectively
    // decomissioning them (since they can no longer deploy books that mint MOON)
    address public factory;

    // Mapping of factory MoonBook minters - by having factory as a key, we can
    // prevent deprecated MoonBooks (e.g. MoonBooks deployed by deprecated factories)
    // from minting MOON rewards
    mapping(address factory => mapping(address minter => bool)) public minters;

    event SeedLiquidity(address indexed caller, uint256 amount);
    event SetFactory(address indexed caller, address indexed factory);
    event AddMinter(address indexed factory, address indexed minter);
    event DepositFees(
        address indexed buyer,
        address indexed seller,
        uint256 amount
    );
    event ClaimFees(
        address indexed caller,
        uint256 amount,
        address indexed recipient
    );

    error InvalidAddress();
    error InvalidAmount();
    error NotFactory();
    error NotMinter();

    constructor(address _owner) Owned(_owner) {
        if (_owner == address(0)) revert InvalidAddress();
    }

    /**
     * @notice Deposit ETH and mint MOON tokens (1:1 ratio)
     */
    function seedLiquidity() external payable onlyOwner {
        if (msg.value == 0) revert InvalidAmount();

        _mint(address(this), msg.value);

        emit SeedLiquidity(msg.sender, msg.value);
    }

    /**
     * @notice Set factory
     * @param  _factory  address  MoonBookFactory contract address
     */
    function setFactory(address _factory) external onlyOwner {
        if (_factory == address(0)) revert InvalidAddress();

        factory = _factory;

        emit SetFactory(msg.sender, _factory);
    }

    /**
     * @notice Add new minter
     * @param  minter  address  Minter address
     */
    function addMinter(address minter) external {
        // Only the factory can add new minters (i.e. MoonBook contracts)
        if (msg.sender != factory) revert NotFactory();

        if (minter == address(0)) revert InvalidAddress();

        minters[factory][minter] = true;

        emit AddMinter(factory, minter);
    }

    /**
     * @notice Deposit ETH fees to distribute MOON rewards
     * @param  buyer        address  Buyer address
     * @param  seller       address  Seller address
     * @return userRewards  uint256  Reward amount for each user
     */
    function depositFees(
        address buyer,
        address seller
    ) external payable returns (uint256 userRewards) {
        if (!minters[factory][msg.sender]) revert NotMinter();
        if (buyer == address(0)) revert InvalidAddress();
        if (seller == address(0)) revert InvalidAddress();

        // No fees, no MOON - return function early
        if (msg.value == 0) return 0;

        // Calculate the total mintable MOON for each user. If the user share is 90%
        // then mint both the buyer and seller 45% of the amount. Remainder goes to the team
        userRewards = msg.value.mulDivDown(USER_SHARE, USER_SHARE_BASE) / 2;

        _mint(buyer, userRewards);
        _mint(seller, userRewards);

        // Mint the remaining amount to the protocol team multisig - due to rounding, the value
        // may be less by 1 than amount * (USER_SHARE_BASE - USER_SHARE) / USER_SHARE_BASE
        _mint(owner, msg.value - (userRewards * 2));

        emit DepositFees(buyer, seller, msg.value);
    }

    /**
     * @notice Claim ETH fees by redeeming MOON tokens
     * @param  amount     uint256  Amount of MOON to redeem for ETH
     * @param  recipient  address  Recipient address
     */
    function claimFees(
        uint256 amount,
        address payable recipient
    ) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidAddress();

        // Reverts if msg.sender does not have enough MOON
        _burn(msg.sender, amount);

        // Send ETH to the recipient, equal to the amount of MOON burned
        recipient.safeTransferETH(amount);

        emit ClaimFees(msg.sender, amount, recipient);
    }
}
