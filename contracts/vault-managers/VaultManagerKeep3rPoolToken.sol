// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../helpers/Math.sol";
import "../helpers/ReentrancyGuard.sol";
import "./VaultManagerParameters.sol";
import "../oracles/OracleSimple.sol";


/**
 * @title VaultManagerKeep3rPoolToken
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
contract VaultManagerKeep3rPoolToken is ReentrancyGuard {
    using SafeMath for uint;

    Vault public immutable vault;
    VaultManagerParameters public immutable vaultManagerParameters;
    OracleSimplePoolToken public immutable keep3rOraclePoolToken;
    uint public constant ORACLE_TYPE = 4;
    uint public constant Q112 = 2 ** 112;

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
        require(vault.getTotalDebt(asset, user) != 0, "Unit Protocol: NOT_SPAWNED_POSITION");
        _;
    }

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _keep3rOraclePoolToken The address of Keep3r-based Oracle for pool tokens
     **/
    constructor(address payable _vaultManagerParameters, address _keep3rOraclePoolToken) public {
        vaultManagerParameters = VaultManagerParameters(_vaultManagerParameters);
        vault = Vault(VaultManagerParameters(_vaultManagerParameters).vaultParameters().vault());
        keep3rOraclePoolToken = OracleSimplePoolToken(_keep3rOraclePoolToken);
    }

    /**
      * @notice Cannot be used for already spawned positions
      * @notice Token using as main collateral must be whitelisted
      * @notice Depositing tokens must be pre-approved to vault address
      * @dev Spawns new positions
      * @dev Adds collaterals to non-spawned positions
      * @notice position actually considered as spawned only when usdpAmount > 0
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral to deposit
      * @param colAmount The amount of COL token to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function spawn(
        address asset,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount
    )
    public
    nonReentrant
    {
        require(usdpAmount != 0, "Unit Protocol: ZERO_BORROWING");

        // check whether the position is spawned
        require(vault.getTotalDebt(asset, msg.sender) == 0, "Unit Protocol: SPAWNED_POSITION");

        // oracle availability check
        require(vault.vaultParameters().isOracleTypeEnabled(ORACLE_TYPE, asset), "Unit Protocol: WRONG_ORACLE_TYPE");

        // USDP minting triggers the spawn of a position
        vault.spawn(asset, msg.sender, ORACLE_TYPE);

        _depositAndBorrow(asset, msg.sender, mainAmount, colAmount, usdpAmount);

        // fire an event
        emit Join(asset, msg.sender, mainAmount, colAmount, usdpAmount);
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
        uint mainAmount,
        uint colAmount,
        uint usdpAmount
    )
    public
    spawned(asset, msg.sender)
    nonReentrant
    {
        require(usdpAmount != 0, "Unit Protocol: ZERO_BORROWING");

        _depositAndBorrow(asset, msg.sender, mainAmount, colAmount, usdpAmount);

        // fire an event
        emit Join(asset, msg.sender, mainAmount, colAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral
      * @dev Repays specified amount of debt
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function withdrawAndRepay(
        address asset,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount
    )
    public
    spawned(asset, msg.sender)
    nonReentrant
    {
        // check usefulness of tx
        require(mainAmount != 0 || colAmount != 0, "Unit Protocol: USELESS_TX");

        uint debt = vault.debts(asset, msg.sender);
        require(debt != 0 && usdpAmount != debt, "Unit Protocol: USE_REPAY_ALL_INSTEAD");

        if (mainAmount != 0) {
            // withdraw main collateral to the user address
            vault.withdrawMain(asset, msg.sender, mainAmount);
        }

        if (colAmount != 0) {
            // withdraw COL tokens to the user's address
            vault.withdrawCol(asset, msg.sender, colAmount);
        }

        if (usdpAmount != 0) {
            uint fee = vault.calculateFee(asset, msg.sender, usdpAmount);
            vault.chargeFee(vault.usdp(), msg.sender, fee);
            vault.repay(asset, msg.sender, usdpAmount);
        }

        vault.update(asset, msg.sender);

        _ensureCollateralizationTroughProofs(asset, msg.sender);

        // fire an event
        emit Exit(asset, msg.sender, mainAmount, colAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP and COL balances and allowances to pay the debt
      * @dev Repays specified amount of debt paying fee in COL
      * @param asset The address of token using as main collateral
      * @param usdpAmount The amount of USDP token to repay
      **/
    function repayUsingCol(
        address asset,
        uint usdpAmount
    )
    public
    spawned(asset, msg.sender)
    nonReentrant
    {
        // check usefulness of tx
        require(usdpAmount != 0, "Unit Protocol: USELESS_TX");

        // COL token price in USD
        uint colUsdValue_q112 = keep3rOraclePoolToken.oracleMainAsset().assetToUsd(vault.col(), 1);

        uint fee = vault.calculateFee(asset, msg.sender, usdpAmount);
        uint feeInCol = fee.mul(Q112).div(colUsdValue_q112);
        vault.chargeFee(vault.col(), msg.sender, feeInCol);
        vault.repay(asset, msg.sender, usdpAmount);

        // fire an event
        emit Exit(asset, msg.sender, 0, 0, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP and COL balances to pay the debt
      * @dev Withdraws collateral
      * @dev Repays specified amount of debt paying fee in COL
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function withdrawAndRepayUsingCol(
        address asset,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount
    )
    public
    spawned(asset, msg.sender)
    nonReentrant
    {
        {
            // check usefulness of tx
            require(mainAmount != 0 || colAmount != 0, "Unit Protocol: USELESS_TX");

            uint debt = vault.debts(asset, msg.sender);
            require(debt != 0 && usdpAmount != debt, "Unit Protocol: USE_REPAY_ALL_INSTEAD");

            if (mainAmount != 0) {
                // withdraw main collateral to the user address
                vault.withdrawMain(asset, msg.sender, mainAmount);
            }

            if (colAmount != 0) {
                // withdraw COL tokens to the user's address
                vault.withdrawCol(asset, msg.sender, colAmount);
            }
        }

        uint colDeposit = vault.colToken(asset, msg.sender);

        // main collateral value of the position in USD
        uint mainUsdValue_q112 = keep3rOraclePoolToken.assetToUsd(asset, vault.collaterals(asset, msg.sender));

        // COL token value of the position in USD
        uint colUsdValue_q112 = keep3rOraclePoolToken.oracleMainAsset().assetToUsd(vault.col(), colDeposit);

        if (usdpAmount != 0) {
            uint fee = vault.calculateFee(asset, msg.sender, usdpAmount);
            uint feeInCol = fee.mul(Q112).mul(colDeposit).div(colUsdValue_q112);
            vault.chargeFee(vault.col(), msg.sender, feeInCol);
            vault.repay(asset, msg.sender, usdpAmount);
        }

        vault.update(asset, msg.sender);

        _ensureCollateralization(asset, msg.sender, mainUsdValue_q112, colUsdValue_q112);

        // fire an event
        emit Exit(asset, msg.sender, mainAmount, colAmount, usdpAmount);
    }

    function _depositAndBorrow(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount
    )
    internal
    {
        if (mainAmount != 0) {
            vault.depositMain(asset, user, mainAmount);
        }

        if (colAmount != 0) {
            vault.depositCol(asset, user, colAmount);
        }

        // mint USDP to user
        vault.borrow(asset, user, usdpAmount);

        // check collateralization
        _ensureCollateralizationTroughProofs(asset, user);
    }

    // ensures that borrowed value is in desired range
    function _ensureCollateralizationTroughProofs(
        address asset,
        address user
    )
    internal
    view
    {
        // main collateral value of the position in USD
        uint mainUsdValue_q112 = keep3rOraclePoolToken.assetToUsd(asset, vault.collaterals(asset, user));

        // COL token value of the position in USD
        uint colUsdValue_q112 = keep3rOraclePoolToken.oracleMainAsset().assetToUsd(vault.col(), vault.colToken(asset, user));

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

        uint minColPercent = vaultManagerParameters.minColPercent(asset);
        if (minColPercent != 0) {
            // main limit by COL
            uint mainUsdLimit_q112 = colUsdValue_q112 * (100 - minColPercent) / minColPercent;
            mainUsdUtilized_q112 = Math.min(mainUsdValue_q112, mainUsdLimit_q112);
        } else {
            mainUsdUtilized_q112 = mainUsdValue_q112;
        }

        uint maxColPercent = vaultManagerParameters.maxColPercent(asset);
        if (maxColPercent < 100) {
            // COL limit by main
            uint colUsdLimit_q112 = mainUsdValue_q112 * maxColPercent / (100 - maxColPercent);
            colUsdUtilized_q112 = Math.min(colUsdValue_q112, colUsdLimit_q112);
        } else {
            colUsdUtilized_q112 = colUsdValue_q112;
        }

        // USD limit of the position
        uint usdLimit = (
            mainUsdUtilized_q112 * vaultManagerParameters.initialCollateralRatio(asset) +
            colUsdUtilized_q112 * vaultManagerParameters.initialCollateralRatio(vault.col())
        ) / Q112 / 100;

        // revert if collateralization is not enough
        require(vault.getTotalDebt(asset, user) <= usdLimit, "Unit Protocol: UNDERCOLLATERALIZED");
    }
}
