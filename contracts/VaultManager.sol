// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./Vault.sol";
import "./oracle/ChainlinkedUniswapOracle.sol";
import "./helpers/Math.sol";


/**
 * @title VaultManager
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
contract VaultManager is Auth {
    using ERC20SafeTransfer for address;
    using SafeMath for uint;

    Vault public vault;
    ChainlinkedUniswapOracle public uniswapOracle;
    address public COL;

    /**
     * @dev Trigger when params joins are happened
    **/
    event Join(address indexed asset, address indexed user, uint main, uint col, uint usdp);

    /**
     * @dev Trigger when params exits are happened
    **/
    event Exit(address indexed asset, address indexed user, uint main, uint col, uint usdp);

    modifier spawned(address asset, address user) {

        // check the existence of a position
        require(vault.getDebt(asset, user) > 0, "USDP: NOT_SPAWNED_POSITION");
        _;
    }

    /**
     * @param _vault The address of the Vault
     * @param _parameters The address of the contract with system parameters
     * @param _uniswapOracle The address of Uniswap-based Oracle
     * @param _col COL token address
     **/
    constructor(
        address _vault,
        address _parameters,
        ChainlinkedUniswapOracle _uniswapOracle,
        address _col
    )
        Auth(_parameters)
        public
    {
        vault = Vault(_vault);
        uniswapOracle = _uniswapOracle;
        COL = _col;
    }

    /**
      * @notice Cannot be used for already spawned positions
      * @notice Token using as main collateral must be whitelisted
      * @notice Depositing tokens must be pre-approved to vault address
      * @dev Spawns new positions
      * @dev Adds collaterals to non-spawned positions
      * @notice position actually spawns when usdpAmount > 0
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral to deposit
      * @param colAmount The amount of COL token to deposit
      * @param usdpAmount The amount of USDP token to borrow
      * @param oracleType The type of an oracle. Initially, only Uniswap is possible (1)
      **/
    function spawn(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        USDPLib.Oracle oracleType,
        USDPLib.ProofData memory mainPriceProof,
        USDPLib.ProofData memory colPriceProof
    )
        public
    {
        require(usdpAmount > 0, "USDP: ZERO_BORROWING");

        // check whether the position is spawned
        require(vault.getDebt(asset, user) == 0, "USDP: SPAWNED_POSITION");

        // oracle availability check
        require(parameters.isOracleTypeEnabled(oracleType, asset), "USDP: WRONG_ORACLE_TYPE");

        // USDP minting triggers the spawn of a position
        vault.spawn(asset, user, oracleType);

        _depositAndBorrow(asset, user, mainAmount, colAmount, usdpAmount, mainPriceProof, colPriceProof);

        // fire an event
        emit Join(asset, user, mainAmount, colAmount, usdpAmount);
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

        // deposit collaterals if needed
        _deposit(asset, user, mainAmount, colAmount);

        // fire an event
        emit Join(asset, user, mainAmount, colAmount, 0);
    }

    /**
     * @notice Position should be spawned (USDP borrowed from position) to call this method
     * @notice Depositing tokens must be pre-approved to vault address
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals to spawned positions
     * @dev Borrows USDP
     * @param asset The address of token using as main collateral
     * @param mainAmount The amount of main collateral to deposit
     * @param colAmount The amount of COL token to deposit
     * @param usdpAmount The amount of USDP token to borrow
     **/
    function depositAndBorrow(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        USDPLib.ProofData memory mainPriceProof,
        USDPLib.ProofData memory colPriceProof
    )
        public
        spawned(asset, user)
    {
        require(usdpAmount > 0, "USDP: ZERO_BORROWING");

        _depositAndBorrow(asset, user, mainAmount, colAmount, usdpAmount, mainPriceProof, colPriceProof);

        // fire an event
        emit Join(asset, user, mainAmount, colAmount, usdpAmount);
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

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral
      * @dev Repays specified amount of debt
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      * @param mainPriceProof The merkle proof of the main collateral price at given block
      * @param colPriceProof The merkle proof of the COL token price at given block
      **/
    function withdrawAndRepay(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        USDPLib.ProofData memory mainPriceProof,
        USDPLib.ProofData memory colPriceProof
    )
        public
        spawned(asset, user)
    {
        // check usefulness of tx
        require(mainAmount > 0 || colAmount > 0, "USDP: USELESS_TX");

        uint debt = vault.getDebt(asset, user);
        require(debt > 0 && usdpAmount != debt, "USDP: USE_REPAY_ALL_INSTEAD");

        vault.update(asset, user);

        if (mainAmount > 0) {
            // withdraw main collateral to the user address
            vault.withdrawMain(asset, user, mainAmount);
        }

        if (colAmount > 0) {
            // withdraw COL tokens to the user's address
            vault.withdrawCol(asset, user, colAmount);
        }

        if (usdpAmount > 0) {
            _repay(asset, user, usdpAmount);
        }

        _ensureCollateralization(asset, user, mainPriceProof, colPriceProof);

        // fire an event
        emit Exit(asset, user, mainAmount, colAmount, usdpAmount);
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

    function _depositAndBorrow(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        USDPLib.ProofData memory mainPriceProof,
        USDPLib.ProofData memory colPriceProof
    )
        internal
    {
        // deposit collaterals if needed
        _deposit(asset, user, mainAmount, colAmount);

        // mint USDP to user
        vault.borrow(asset, user, usdpAmount);

        // check collateralization
        _ensureCollateralization(asset, user, mainPriceProof, colPriceProof);
    }

    function _deposit(address asset, address user, uint mainAmount, uint colAmount) internal {
        if (mainAmount > 0) {
            vault.depositMain(asset, user, mainAmount);
        }

        if (colAmount > 0) {
            vault.depositCol(asset, user, colAmount);
        }
    }

    // ensures that borrowed value is in desired range
    function _ensureCollateralization(
        address asset,
        address user,
        USDPLib.ProofData memory mainPriceProof,
        USDPLib.ProofData memory colPriceProof
    )
        internal
        view
    {
        // COL token value of the position in USD
        uint colUsdValue = uniswapOracle.assetToUsd(COL, vault.colToken(asset, user), colPriceProof);

        // main collateral value of the position in USD
        uint mainUsdValue = uniswapOracle.assetToUsd(asset, vault.collaterals(asset, user), mainPriceProof);

        uint mainUsdUtilized;
        uint colUsdUtilized;

        uint minColPercent = parameters.minColPercent(asset);
        if (minColPercent > 0) {
            // main limit by COL
            uint mainUsdLimit = colUsdValue * (100 - minColPercent) / minColPercent;
            mainUsdUtilized = Math.min(mainUsdValue, mainUsdLimit);
        } else {
            mainUsdUtilized = mainUsdValue;
        }

        uint maxColPercent = parameters.maxColPercent(asset);
        if (maxColPercent < 100) {
            // COL limit by main
            uint colUsdLimit = mainUsdValue * maxColPercent / (100 - maxColPercent);
            colUsdUtilized = Math.min(colUsdValue, colUsdLimit);
        } else {
            colUsdUtilized = colUsdValue;
        }

        uint mainICR = parameters.initialCollateralRatio(asset);
        uint colICR = parameters.initialCollateralRatio(COL);

        // USD limit of the position
        uint usdLimit = (mainUsdUtilized * mainICR + colUsdUtilized * colICR) / 100;

        // revert if collateralization is not enough
        require(vault.getDebt(asset, user) <= usdLimit, "USDP: UNDERCOLLATERALIZED");
    }
}
