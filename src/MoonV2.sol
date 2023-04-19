// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface UserModule {
    function deposit(uint256, address) external returns (uint256);
}

contract Moon is ERC20("Redeemable Token", "MOON", 18) {
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

    // Lido stETH proxy contract address
    address payable public constant LIDO =
        payable(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    // Instadapp proxy contract address
    UserModule public constant INSTADAPP =
        UserModule(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);

    address public immutable protocolTeam;

    event DepositETH(
        address indexed msgSender,
        uint256 msgValue,
        uint256 shares
    );

    error InvalidAddress();
    error InvalidAmount();

    constructor(address _protocolTeam) {
        if (_protocolTeam == address(0)) revert InvalidAddress();

        protocolTeam = _protocolTeam;

        // Enables Instadapp to transfer stETH on our behalf when depositing
        ERC20(LIDO).safeApprove(address(INSTADAPP), type(uint256).max);
    }

    /**
     * @notice Deposit ETH, receive MOON
     * @return shares  uint256  Instadapp shares minted from ETH deposit
     */
    function depositETH() external payable returns (uint256 shares) {
        if (msg.value == 0) revert InvalidAmount();

        // Stake ETH in Lido
        LIDO.safeTransferETH(msg.value);

        // Deposit stETH into Instadapp to maximize returns
        shares = INSTADAPP.deposit(
            ERC20(LIDO).balanceOf(address(this)),
            address(this)
        );

        // Mint MOON for msg.sender, equal to the Instadapp shares received
        _mint(msg.sender, shares);

        emit DepositETH(msg.sender, msg.value, shares);
    }
}
