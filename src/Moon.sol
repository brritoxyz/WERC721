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

    // Fixed parameters for calculating user MOON reward amounts
    uint256 public constant USER_SHARE_BASE = 10_000;

    // Max MOON allocated to users is 90%
    uint128 public constant MAX_USER_SHARE = 9_000;

    // Min MOON allocated to users is 50%
    uint128 public constant MIN_USER_SHARE = 5_000;

    // Used for calculating the mintable MOON amounts for user (default is 90% of all MOON)
    uint96 public userShare = 9_000;

    // Factories deploy MoonBook contracts and enable them to mint MOON rewards
    // When factories are upgraded, they are set as the new factory
    // Old factories will no longer be able to call `addMinter`, effectively
    // decomissioning them (since they can no longer deploy books that mint MOON)
    address public factory;

    // Time interval (seconds) between snapshots
    uint64 public snapshotInterval = 1 hours;

    // Last snapshot timestamp
    uint64 public lastSnapshotAt;

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

    event SetUserShare(uint96 userShare);
    event SetSnapshotInterval(uint64 snapshotInterval);
    event SetFactory(address indexed factory);
    event AddMinter(address indexed factory, address indexed minter);
    event DepositFees(
        address indexed buyer,
        address indexed seller,
        uint256 amount
    );

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

    function setUserShare(uint96 _userShare) external onlyOwner {
        if (_userShare > MAX_USER_SHARE) revert InvalidAmount();
        if (_userShare < MIN_USER_SHARE) revert InvalidAmount();

        userShare = _userShare;

        emit SetUserShare(_userShare);
    }

    function setSnapshotInterval(uint64 _snapshotInterval) external onlyOwner {
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
        lastSnapshotAt = block.timestamp.safeCastTo64();

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
     * @notice Deposit exchange fees, and distribute MOON rewards
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

        // Track fees accrued since the last snapshot, which will be claimable
        // by MOON holders after the next snapshot is taken
        feesSinceLastSnapshot += msg.value.safeCastTo128();

        // Calculate the total mintable MOON for each user. If the user share is 90%
        // then each user will be able to mint 45% of the amount. Remainder goes to the team
        userRewards = msg.value.mulDivDown(userShare, USER_SHARE_BASE) / 2;

        // Increase the mintable amounts for users, who must later manually claim/mint MOON
        mintable[buyer] += userRewards;
        mintable[seller] += userRewards;

        // Mint the remaining amount to the protocol team multisig - due to rounding, the
        // value may be less than amount * (USER_SHARE_BASE - userShare) / USER_SHARE_BASE
        _mint(owner, msg.value - (userRewards * 2));

        emit DepositFees(buyer, seller, msg.value);
    }
}
