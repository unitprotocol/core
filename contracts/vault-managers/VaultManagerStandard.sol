// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../helpers/Math.sol";
import "../helpers/ReentrancyGuard.sol";


/**
 * @title VaultManagerStandard
 **/
contract VaultManagerStandard is ReentrancyGuard {
    using SafeMath for uint;

    Vault public immutable vault;

    /**
     * @dev Trigger when params joins are happened
    **/
    event Join(address indexed asset, address indexed user, uint main, uint usdp);

    /**
     * @dev Trigger when params exits are happened
    **/
    event Exit(address indexed asset, address indexed user, uint main, uint usdp);

    /**
     * @param _vault The address of the Vault
     **/
    constructor(address payable _vault) public {
        vault = Vault(_vault);
    }

    /**
     * @notice Depositing token must be pre-approved to vault address
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals
     * @param asset The address of token using as main collateral
     * @param mainAmount The amount of main collateral to deposit
     **/
    function deposit(address asset, uint mainAmount) public nonReentrant {

        // check usefulness of tx
        require(mainAmount != 0, "Unit Protocol: USELESS_TX");

        vault.depositMain(asset, msg.sender, mainAmount);

        // fire an event
        emit Join(asset, msg.sender, mainAmount, 0);
    }

    /**
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals converting ETH to WETH
     **/
    function deposit_Eth() public payable nonReentrant {

        // check usefulness of tx
        require(msg.value != 0, "Unit Protocol: USELESS_TX");

        vault.depositEth{value: msg.value}(msg.sender);

        // fire an event
        emit Join(vault.weth(), msg.sender, msg.value, 0);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Repays specified amount of debt
      * @param asset The address of token using as main collateral
      * @param usdpAmount The amount of USDP token to repay
      **/
    function repay(address asset, uint usdpAmount) public nonReentrant {

        // check usefulness of tx
        require(usdpAmount != 0, "Unit Protocol: USELESS_TX");

        _repay(asset, msg.sender, usdpAmount);

        // fire an event
        emit Exit(asset, msg.sender, 0, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @notice USDP approval is NOT needed
      * @dev Repays total debt and withdraws collaterals
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      **/
    function repayAllAndWithdraw(
        address asset,
        uint mainAmount
    )
    external
    nonReentrant
    {
        uint debtAmount = vault.debts(asset, msg.sender);

        if (mainAmount != 0) {
            // withdraw main collateral to the user address
            vault.withdrawMain(asset, msg.sender, mainAmount);
        }

        if (debtAmount != 0) {
            // burn USDP from the user's address
            _repay(asset, msg.sender, debtAmount);
        }

        // fire an event
        emit Exit(asset, msg.sender, mainAmount, debtAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @notice USDP approval is NOT needed
      * @dev Repays total debt and withdraws collaterals
      * @param ethAmount The ETH amount to withdraw
      **/
    function repayAllAndWithdraw_Eth(
        uint ethAmount
    )
    external
    nonReentrant
    {
        uint debtAmount = vault.debts(vault.weth(), msg.sender);

        if (ethAmount != 0) {
            // withdraw ETH to the user address
            vault.withdrawEth(msg.sender, ethAmount);
        }

        if (debtAmount != 0) {
            // burn USDP from the user's address
            _repay(vault.weth(), msg.sender, debtAmount);
        }

        // fire an event
        emit Exit(vault.weth(), msg.sender, ethAmount, debtAmount);
    }

    // decreases debt
    function _repay(address asset, address user, uint usdpAmount) internal {
        uint fee = vault.calculateFee(asset, user, usdpAmount);
        vault.chargeFee(vault.usdp(), user, fee);

        // burn USDP from the user's balance
        uint debtAfter = vault.repay(asset, user, usdpAmount);
        if (debtAfter == 0) {
            // clear unused storage
            vault.destroy(asset, user);
        }
    }
}
