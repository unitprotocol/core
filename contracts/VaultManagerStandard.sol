// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./Vault.sol";
import "./helpers/Math.sol";


/**
 * @title VaultManager
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
contract VaultManagerStandard is Auth {
    using ERC20SafeTransfer for address;
    using SafeMath for uint;

    Vault public vault;
    address public COL;

    /**
     * @dev Trigger when params joins are happened
    **/
    event Join(address indexed asset, address indexed user, uint main, uint col, uint usdp);

    /**
     * @dev Trigger when params exits are happened
    **/
    event Exit(address indexed asset, address indexed user, uint main, uint col, uint usdp);

    /**
     * @param _vault The address of the Vault
     * @param _parameters The address of the contract with system parameters
     * @param _col COL token address
     **/
    constructor(
        address _vault,
        address _parameters,
        address _col
    )
        Auth(_parameters)
        public
    {
        vault = Vault(_vault);
        COL = _col;
    }

    /**
     * @notice Depositing tokens must be pre-approved to vault address
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals
     * @param asset The address of token using as main collateral
     * @param mainAmount The amount of main collateral to deposit
     * @param colAmount The amount of COL token to deposit
     **/
    function deposit(address asset, address user, uint mainAmount, uint colAmount) public {

        // check usefulness of tx
        require(mainAmount > 0 || colAmount > 0, "USDP: USELESS_TX");

        if (mainAmount > 0) {
            vault.depositMain(asset, user, mainAmount);
        }

        if (colAmount > 0) {
            vault.depositCol(asset, user, colAmount);
        }

        // fire an event
        emit Join(asset, user, mainAmount, colAmount, 0);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Repays specified amount of debt
      * @param asset The address of token using as main collateral
      * @param usdpAmount The amount of USDP token to repay
      **/
    function repay(address asset, address user, uint usdpAmount) public {

        // check usefulness of tx
        require(usdpAmount > 0, "USDP: USELESS_TX");

        _repay(asset, user, usdpAmount);

        // fire an event
        emit Exit(asset, user, 0, 0, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @notice Token approwal is NOT needed
      * @notice Merkle proofs are NOT needed since we don't need to check collateralization (cause there is no debt yet)
      * @dev Repays total debt and withdraws collaterals
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      **/
    function repayAllAndWithdraw(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount
    )
        external
    {
        uint debtAmount = vault.getDebt(asset, user);

        if (mainAmount == 0 && colAmount == 0) {
            // just repay the debt
            return repay(asset, user, debtAmount);
        }

        if (mainAmount > 0) {
            // withdraw main collateral to the user address
            vault.withdrawMain(asset, user, mainAmount);
        }

        if (colAmount > 0) {
            // withdraw COL tokens to the user's address
            vault.withdrawCol(asset, user, colAmount);
        }

        if (debtAmount > 0) {
            // burn USDP from the user's address
            _repay(asset, user, debtAmount);
        }

        // fire an event
        emit Exit(asset, user, mainAmount, colAmount, debtAmount);
    }

    // decreases debt
    function _repay(address asset, address user, uint usdpAmount) internal returns(uint) {

        // burn USDP from the user's balance
        uint debtAfter = vault.repay(asset, user, usdpAmount);
        if (debtAfter == 0) {
            // clear unused storage
            vault.destroy(asset, user);
        }

        return debtAfter;
    }
}
