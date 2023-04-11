// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Snapshot} from "src/lib/ERC20Snapshot.sol";
import {ERC20} from "src/lib/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract Moon is ERC20Snapshot, Owned, ReentrancyGuard {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    uint256 public constant USER_SHARE_BASE = 10000;

    // Maximum percent share of MOON rewards that are reserved for users (i.e. buyers and sellers)
    uint128 public MAX_USER_SHARE = 9000;

    // Used for calculating the mintable MOON amounts for user (default is 90% of all MOON)
    uint128 public userShare = 9000;

    // Factories deploy MoonBook contracts and enable them to mint MOON rewards
    // When factories are upgraded, they are set as the new factory
    // Old factories will no longer be able to call `addMinter`, effectively
    // decomissioning them (since they can no longer deploy books that mint MOON)
    address public factory;

    // Time interval (seconds) between snapshots
    uint96 public snapshotInterval = 1 hours;

    // Last snapshot timestamp
    uint128 public lastSnapshotAt;

    // Fees accrued since the last snapshot
    uint128 public feesSinceLastSnapshot;

    // Snapshot IDs mapped to fees accrued at that snapshot
    mapping(uint256 => uint256) public feeSnapshots;

    // Mapping of factory MoonBook minters - by having factory as a key, we can
    // prevent deprecated MoonBooks (e.g. MoonBooks deployed by deprecated factories)
    // from minting MOON rewards
    mapping(address factory => mapping(address minter => bool)) public minters;

    // Tracks the amount of mintable MOON for each user
    mapping(address user => uint256 mintable) public mintable;

    event SetUserShare(uint128 userShare);
    event SetSnapshotInterval(uint96 snapshotInterval);
    event SetFactory(address indexed factory);
    event AddMinter(address indexed factory, address indexed minter);
    event Mint(address indexed buyer, address indexed seller, uint256 amount);

    error InvalidAddress();
    error InvalidAmount();
    error CannotSnapshot();
    error NotFactory();
    error NotMinter();

    constructor(
        address _owner
    ) Owned(_owner) ERC20("Moonbase Token", "MOON", 18) {
        if (_owner == address(0)) revert InvalidAddress();
    }

    function setUserShare(uint128 _userShare) external onlyOwner {
        if (_userShare > MAX_USER_SHARE) revert InvalidAmount();

        userShare = _userShare;

        emit SetUserShare(_userShare);
    }

    function setSnapshotInterval(uint96 _snapshotInterval) external onlyOwner {
        if (_snapshotInterval == 0) revert InvalidAmount();

        snapshotInterval = _snapshotInterval;

        emit SetSnapshotInterval(_snapshotInterval);
    }

    function _snapshot() internal override returns (uint256) {
        // Only allow snapshots to be taken at set intervals (i.e. 1 hour)
        // Return the current snapshot ID either way
        if (lastSnapshotAt + snapshotInterval > block.timestamp)
            return _currentSnapshotId;

        // Update the last snapshot timestamp
        lastSnapshotAt = block.timestamp.safeCastTo128();

        // Increment the current snapshot ID
        uint256 currentId = ++_currentSnapshotId;

        // Store the accrued fee amount to the current snapshot ID
        feeSnapshots[currentId] = feesSinceLastSnapshot;

        // Reset the fee accrual tracker variable to 0 for the next snapshot
        feesSinceLastSnapshot = 0;

        emit Snapshot(currentId);

        return currentId;
    }

    function getSnapshotId() external view returns (uint256) {
        return _currentSnapshotId;
    }

    function snapshot() external returns (uint256) {
        return _snapshot();
    }

    /**
     * @notice Deposit ETH fees
     */
    function depositFees() external payable {
        // Track fees accrued since the last snapshot, which will be claimable
        // by MOON holders after the next snapshot is taken
        feesSinceLastSnapshot += msg.value.safeCastTo128();
    }

    /**
     * @notice Set factory
     * @param  _factory  address  MoonBookFactory contract address
     */
    function setFactory(address _factory) external onlyOwner {
        if (_factory == address(0)) revert InvalidAddress();

        factory = _factory;

        emit SetFactory(_factory);
    }

    /**
     * @notice Add new minter
     * @param  minter  address  Minter address
     */
    function addMinter(address minter) external {
        if (msg.sender != factory) revert NotFactory();
        if (minter == address(0)) revert InvalidAddress();

        minters[factory][minter] = true;

        emit AddMinter(factory, minter);
    }

    /**
     * @notice Overridden _mint with the Transfer event emission removed (to reduce gas)
     * @param  to      address  Recipient address
     * @param  amount  uint256  Mint amount
     */
    function _mint(address to, uint256 amount) internal override {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }
    }

    /**
     * @notice Increase the mintable MOON amounts for users, and mint MOON for team
     * @param  buyer        address  Buyer address
     * @param  seller       address  Seller address
     * @param  amount       uint256  Total reward amount
     * @return userRewards  uint256  Reward amount for each user
     */
    function mint(
        address buyer,
        address seller,
        uint256 amount
    ) external returns (uint256 userRewards) {
        if (!minters[factory][msg.sender]) revert NotMinter();
        if (buyer == address(0)) revert InvalidAddress();
        if (seller == address(0)) revert InvalidAddress();

        // TODO: Consider returning the function early if amount is less than 2
        if (amount == 0) revert InvalidAmount();

        // Calculate the total mintable MOON for each user. If the user share is 90%
        // then each user will be able to mint 45% of the amount. Remainder goes to the team
        userRewards = amount.mulDivDown(userShare, USER_SHARE_BASE) / 2;

        // Increase the mintable amounts for users, who must later manually claim/mint MOON
        mintable[buyer] += userRewards;
        mintable[seller] += userRewards;

        // Mint the remaining amount to the protocol team multisig - due to rounding, the
        // value may be less than amount * (USER_SHARE_BASE - userShare) / USER_SHARE_BASE
        _mint(owner, amount - (userRewards * 2));

        emit Mint(buyer, seller, amount);
    }
}
