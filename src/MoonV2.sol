// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface UserModule {
    function deposit(uint256, address) external returns (uint256);
}

contract Moon is ERC20("Redeemable Token", "MOON", 18), ReentrancyGuard {
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

    // Lido stETH proxy contract address
    address payable public constant LIDO =
        payable(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    // Instadapp proxy contract address
    UserModule public constant INSTADAPP =
        UserModule(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);

    address public immutable protocolTeam;

    event StakeETH(address indexed msgSender, uint256 assets, uint256 shares);
    event DepositETH(address indexed msgSender, uint256 msgValue);

    error InvalidAddress();
    error InvalidAmount();

    constructor(address _protocolTeam) {
        if (_protocolTeam == address(0)) revert InvalidAddress();

        protocolTeam = _protocolTeam;

        // Enables Instadapp to transfer stETH on our behalf when depositing
        ERC20(LIDO).safeApprove(address(INSTADAPP), type(uint256).max);
    }

    function stakeETH() external nonReentrant {
        // Stake ETH balance with Lido
        LIDO.safeTransferETH(address(this).balance);

        // stETH balance to deposit into the Instadapp vault
        uint256 assets = ERC20(LIDO).balanceOf(address(this));

        // Maximize returns with Instadapp
        uint256 shares = INSTADAPP.deposit(assets, address(this));

        emit StakeETH(msg.sender, assets, shares);
    }

    /**
     * @notice Deposit ETH, receive MOON
     */
    function depositETH() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();

        // Mint MOON for msg.sender, equal to the ETH deposited
        _mint(msg.sender, msg.value);

        emit DepositETH(msg.sender, msg.value);
    }
}
