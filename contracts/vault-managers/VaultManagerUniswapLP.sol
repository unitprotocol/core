// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../oracles/ChainlinkedUniswapOracleLP.sol";
import "../helpers/Math.sol";


/**
 * @title VaultManagerUniswapLP
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
contract VaultManagerUniswapLP is Auth {
    using ERC20SafeTransfer for address;
    using SafeMath for uint;

    Vault public vault;
    ChainlinkedUniswapOracleLP public uniswapLPOracle;
    uint public constant ORACLE_TYPE = 2;

    /**
     * @dev Trigger when joins are happened
    **/
    event Join(address indexed asset, address indexed user, uint main, uint col, uint usdp);

    /**
     * @dev Trigger when exits are happened
    **/
    event Exit(address indexed asset, address indexed user, uint main, uint col, uint usdp);

    modifier spawned(address asset, address user) {

        // check the existence of a position
        require(vault.getTotalDebt(asset, user) > 0, "USDP: NOT_SPAWNED_POSITION");
        _;
    }

    /**
     * @param _vault The address of the Vault
     * @param _uniswapOracle The address of Uniswap-based Oracle for LP tokens
     **/
    constructor(
        address _vault,
        ChainlinkedUniswapOracleLP _uniswapOracle
    )
        Auth(address(Vault(_vault).parameters()))
        public
    {
        vault = Vault(_vault);
        uniswapLPOracle = _uniswapOracle;
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
      * @param underlyingProof The merkle proof data of the underlying collateral token price
      * @param colProof The merkle proof data of the COL token price
      **/
    function spawn(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory underlyingProof,
        UniswapOracle.ProofData memory colProof
    )
        public
    {
        require(usdpAmount > 0, "USDP: ZERO_BORROWING");

        // check whether the position is spawned
        require(vault.getTotalDebt(asset, user) == 0, "USDP: SPAWNED_POSITION");

        // oracle availability check
        require(parameters.isOracleTypeEnabled(ORACLE_TYPE, asset), "USDP: WRONG_ORACLE_TYPE");

        // USDP minting triggers the spawn of a position
        vault.spawn(asset, user, ORACLE_TYPE);

        _depositAndBorrow(asset, user, mainAmount, colAmount, usdpAmount, underlyingProof, colProof);

        // fire an event
        emit Join(asset, user, mainAmount, colAmount, usdpAmount);
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
     * @param underlyingProof The merkle proof data of the underlying collateral token price
     * @param colProof The merkle proof data of the COL token price
     **/
    function depositAndBorrow(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory underlyingProof,
        UniswapOracle.ProofData memory colProof
    )
        public
        spawned(asset, user)
    {
        require(usdpAmount > 0, "USDP: ZERO_BORROWING");

        _depositAndBorrow(asset, user, mainAmount, colAmount, usdpAmount, underlyingProof, colProof);

        // fire an event
        emit Join(asset, user, mainAmount, colAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral
      * @dev Repays specified amount of debt
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      * @param underlyingProof The merkle proof data of the underlying collateral token price
      * @param colProof The merkle proof data of the COL token price
      **/
    function withdrawAndRepay(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory underlyingProof,
        UniswapOracle.ProofData memory colProof
    )
        public
        spawned(asset, user)
    {
        // check usefulness of tx
        require(mainAmount > 0 || colAmount > 0, "USDP: USELESS_TX");

        uint debt = vault.debts(asset, user);
        require(debt > 0 && usdpAmount != debt, "USDP: USE_REPAY_ALL_INSTEAD");

        if (mainAmount > 0) {
            // withdraw main collateral to the user address
            vault.withdrawMain(asset, user, mainAmount);
        }

        if (colAmount > 0) {
            // withdraw COL tokens to the user's address
            vault.withdrawCol(asset, user, colAmount);
        }

        if (usdpAmount > 0) {
            uint fee = vault.calculateFee(asset, user, usdpAmount);
            vault.chargeFee(address(vault.usdp()), user, fee);
            vault.repay(asset, user, usdpAmount);
        }

        vault.update(asset, user);

        _ensureCollateralizationTroughProofs(asset, user, underlyingProof, colProof);

        // fire an event
        emit Exit(asset, user, mainAmount, colAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP and COL balances to pay the debt
      * @dev Withdraws collateral
      * @dev Repays specified amount of debt paying fee in COL
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      * @param underlyingProof The merkle proof data of the underlying collateral token price
      * @param colProof The merkle proof data of the COL token price
      **/
    function withdrawAndRepayUsingCol(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory underlyingProof,
        UniswapOracle.ProofData memory colProof
    )
        public
        spawned(asset, user)
    {
        {
            // check usefulness of tx
            require(mainAmount > 0 || colAmount > 0, "USDP: USELESS_TX");

            uint debt = vault.debts(asset, user);
            require(debt > 0 && usdpAmount != debt, "USDP: USE_REPAY_ALL_INSTEAD");

            if (mainAmount > 0) {
                // withdraw main collateral to the user address
                vault.withdrawMain(asset, user, mainAmount);
            }

            if (colAmount > 0) {
                // withdraw COL tokens to the user's address
                vault.withdrawCol(asset, user, colAmount);
            }
        }

        uint colDeposit = vault.colToken(asset, user);

        // main collateral value of the position in USD
        uint mainUsdValue_q112 = uniswapLPOracle.assetToUsd(asset, vault.collaterals(asset, user), underlyingProof);

        // COL token value of the position in USD
        uint colUsdValue_q112 = uniswapLPOracle.chainlinkedUniswapOracle().assetToUsd(vault.col(), colDeposit, colProof);

        if (usdpAmount > 0) {
            uint fee = vault.calculateFee(asset, user, usdpAmount);
            uint feeInCol = fee.mul(uniswapLPOracle.Q112()).mul(colDeposit).div(colUsdValue_q112);
            vault.chargeFee(address(vault.col()), user, feeInCol);
            vault.repay(asset, user, usdpAmount);
        }

        vault.update(asset, user);

        _ensureCollateralization(asset, user, mainUsdValue_q112, colUsdValue_q112);

        // fire an event
        emit Exit(asset, user, mainAmount, colAmount, usdpAmount);
    }

    function _depositAndBorrow(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory underlyingProof,
        UniswapOracle.ProofData memory colProof
    )
        internal
    {
        if (mainAmount > 0) {
            vault.depositMain(asset, user, mainAmount);
        }

        if (colAmount > 0) {
            vault.depositCol(asset, user, colAmount);
        }

        // mint USDP to user
        vault.borrow(asset, user, usdpAmount);

        // check collateralization
        _ensureCollateralizationTroughProofs(asset, user, underlyingProof, colProof);
    }

    // ensures that borrowed value is in desired range
    function _ensureCollateralizationTroughProofs(
        address asset,
        address user,
        UniswapOracle.ProofData memory underlyingProof,
        UniswapOracle.ProofData memory colProof
    )
        internal
        view
    {
        // main collateral value of the position in USD
        uint mainUsdValue_q112 = uniswapLPOracle.assetToUsd(asset, vault.collaterals(asset, user), underlyingProof);

        // COL token value of the position in USD
        uint colUsdValue_q112 = uniswapLPOracle.chainlinkedUniswapOracle().assetToUsd(vault.col(), vault.colToken(asset, user), colProof);

        _ensureCollateralization(asset, user, mainUsdValue_q112, colUsdValue_q112);
    }

    // ensures that borrowed value is in desired range
    function _ensureCollateralization(
        address asset,
        address user,
        uint mainUsdValue_q112,
        uint colUsdValue_q112
    )
        internal
        view
    {
        uint mainUsdUtilized_q112;
        uint colUsdUtilized_q112;

        uint minColPercent = parameters.minColPercent(asset);
        if (minColPercent > 0) {
            // main limit by COL
            uint mainUsdLimit_q112 = colUsdValue_q112 * (100 - minColPercent) / minColPercent;
            mainUsdUtilized_q112 = Math.min(mainUsdValue_q112, mainUsdLimit_q112);
        } else {
            mainUsdUtilized_q112 = mainUsdValue_q112;
        }

        uint maxColPercent = parameters.maxColPercent(asset);
        if (maxColPercent < 100) {
            // COL limit by main
            uint colUsdLimit_q112 = mainUsdValue_q112 * maxColPercent / (100 - maxColPercent);
            colUsdUtilized_q112 = Math.min(colUsdValue_q112, colUsdLimit_q112);
        } else {
            colUsdUtilized_q112 = colUsdValue_q112;
        }

        // USD limit of the position
        uint usdLimit = (
            mainUsdUtilized_q112 * parameters.initialCollateralRatio(asset) +
            colUsdUtilized_q112 * parameters.initialCollateralRatio(vault.col())
        ) / uniswapLPOracle.Q112() / 100;

        // revert if collateralization is not enough
        require(vault.getTotalDebt(asset, user) <= usdLimit, "USDP: UNDERCOLLATERALIZED");
    }
}
