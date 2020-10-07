// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../oracles/ChainlinkedUniswapOracleMainAsset.sol";
import "../helpers/Math.sol";
import "../helpers/ReentrancyGuard.sol";


/**
 * @title VaultManagerUniswapMainAsset
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
contract VaultManagerUniswapMainAsset is Auth, ReentrancyGuard {
    using ERC20SafeTransfer for address;
    using SafeMath for uint;

    Vault public vault;
    ChainlinkedUniswapOracleMainAsset public uniswapOracle;
    uint public constant ORACLE_TYPE = 1;
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
        require(vault.getTotalDebt(asset, user) != 0, "USDP: NOT_SPAWNED_POSITION");
        _;
    }

    /**
     * @param _vault The address of the Vault
     * @param _parameters The address of the contract with system parameters
     * @param _uniswapOracle The address of Uniswap-based Oracle
     **/
    constructor(
        address payable _vault,
        address _parameters,
        address _uniswapOracle
    )
        Auth(_parameters)
        public
    {
        vault = Vault(_vault);
        uniswapOracle = ChainlinkedUniswapOracleMainAsset(_uniswapOracle);
    }

    /**
      * @notice Cannot be used for already spawned positions
      * @notice Token using as main collateral must be whitelisted
      * @notice Depositing tokens must be pre-approved to vault address
      * @notice position actually considered as spawned only when usdpAmount > 0
      * @dev Spawns new positions
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral to deposit
      * @param colAmount The amount of COL token to deposit
      * @param usdpAmount The amount of USDP token to borrow
      * @param mainPriceProof The merkle proof of the main collateral price
      **/
    function spawn(
        address asset,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory mainPriceProof,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        nonReentrant
    {
        require(usdpAmount != 0, "USDP: ZERO_BORROWING");

        // check whether the position is spawned
        require(vault.getTotalDebt(asset, msg.sender) == 0, "USDP: SPAWNED_POSITION");

        // oracle availability check
        require(parameters.isOracleTypeEnabled(ORACLE_TYPE, asset), "USDP: WRONG_ORACLE_TYPE");

        // USDP minting triggers the spawn of a position
        vault.spawn(asset, msg.sender, ORACLE_TYPE);

        _depositAndBorrow(asset, msg.sender, mainAmount, colAmount, usdpAmount, mainPriceProof, colPriceProof);

        // fire an event
        emit Join(asset, msg.sender, mainAmount, colAmount, usdpAmount);
    }

    /**
      * @notice Cannot be used for already spawned positions
      * @notice WETH must be whitelisted as collateral
      * @notice COL must be pre-approved to vault address
      * @notice position actually considered as spawned only when usdpAmount > 0
      * @dev Spawns new positions using ETH
      * @param colAmount The amount of COL token to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function spawn_Eth(
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        payable
        nonReentrant
    {
        require(usdpAmount != 0, "USDP: ZERO_BORROWING");

        // check whether the position is spawned
        require(vault.getTotalDebt(vault.weth(), msg.sender) == 0, "USDP: SPAWNED_POSITION");

        // oracle availability check
        require(parameters.isOracleTypeEnabled(ORACLE_TYPE, vault.weth()), "USDP: WRONG_ORACLE_TYPE");

        // USDP minting triggers the spawn of a position
        vault.spawn(vault.weth(), msg.sender, ORACLE_TYPE);

        _depositAndBorrow_Eth(msg.sender, colAmount, usdpAmount, colPriceProof);

        // fire an event
        emit Join(vault.weth(), msg.sender, msg.value, colAmount, usdpAmount);
    }

    /**
     * @notice Position should be spawned (USDP borrowed from position) to call this method
     * @notice Depositing tokens must be pre-approved to vault address
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals and borrows USDP to spawned positions simultaneously
     * @param asset The address of token using as main collateral
     * @param mainAmount The amount of main collateral to deposit
     * @param colAmount The amount of COL token to deposit
     * @param usdpAmount The amount of USDP token to borrow
     * @param mainPriceProof The merkle proof of the main collateral price
     * @param colPriceProof The merkle proof of the COL token price
     **/
    function depositAndBorrow(
        address asset,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory mainPriceProof,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        spawned(asset, msg.sender)
        nonReentrant
    {
        require(usdpAmount != 0, "USDP: ZERO_BORROWING");

        _depositAndBorrow(asset, msg.sender, mainAmount, colAmount, usdpAmount, mainPriceProof, colPriceProof);

        // fire an event
        emit Join(asset, msg.sender, mainAmount, colAmount, usdpAmount);
    }

    /**
     * @notice Position should be spawned (USDP borrowed from position) to call this method
     * @notice Depositing tokens must be pre-approved to vault address
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals and borrows USDP to spawned positions simultaneously
     * @param colAmount The amount of COL token to deposit
     * @param usdpAmount The amount of USDP token to borrow
     * @param colPriceProof The merkle proof of the COL token price
     **/
    function depositAndBorrow_Eth(
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        payable
        spawned(vault.weth(), msg.sender)
        nonReentrant
    {
        require(usdpAmount != 0, "USDP: ZERO_BORROWING");

        _depositAndBorrow_Eth(msg.sender, colAmount, usdpAmount, colPriceProof);

        // fire an event
        emit Join(vault.weth(), msg.sender, msg.value, colAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral and repays specified amount of debt simultaneously
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      * @param mainPriceProof The merkle proof of the main collateral price at given block
      * @param colPriceProof The merkle proof of the COL token price at given block
      **/
    function withdrawAndRepay(
        address asset,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory mainPriceProof,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        spawned(asset, msg.sender)
        nonReentrant
    {
        // check usefulness of tx
        require(mainAmount != 0 || colAmount != 0, "USDP: USELESS_TX");

        uint debt = vault.debts(asset, msg.sender);
        require(debt != 0 && usdpAmount != debt, "USDP: USE_REPAY_ALL_INSTEAD");

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
            vault.chargeFee(address(vault.usdp()), msg.sender, fee);
            vault.repay(asset, msg.sender, usdpAmount);
        }

        vault.update(asset, msg.sender);

        _ensureCollateralizationTroughProofs(asset, msg.sender, mainPriceProof, colPriceProof);

        // fire an event
        emit Exit(asset, msg.sender, mainAmount, colAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral and repays specified amount of debt simultaneously converting WETH to ETH
      * @param ethAmount The amount of ETH to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      * @param colPriceProof The merkle proof of the COL token price
      **/
    function withdrawAndRepay_Eth(
        uint ethAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        spawned(vault.weth(), msg.sender)
        nonReentrant
    {
        // check usefulness of tx
        require(ethAmount != 0 || colAmount != 0, "USDP: USELESS_TX");

        uint debt = vault.debts(vault.weth(), msg.sender);
        require(debt != 0 && usdpAmount != debt, "USDP: USE_REPAY_ALL_INSTEAD");

        if (ethAmount != 0) {
            // withdraw main collateral to the user address
            vault.withdrawEth(msg.sender, ethAmount);
        }

        if (colAmount != 0) {
            // withdraw COL tokens to the user's address
            vault.withdrawCol(vault.weth(), msg.sender, colAmount);
        }

        if (usdpAmount != 0) {
            uint fee = vault.calculateFee(vault.weth(), msg.sender, usdpAmount);
            vault.chargeFee(address(vault.usdp()), msg.sender, fee);
            vault.repay(vault.weth(), msg.sender, usdpAmount);
        }

        vault.update(vault.weth(), msg.sender);

        _ensureCollateralizationTroughProofs_Eth(msg.sender, colPriceProof);

        // fire an event
        emit Exit(vault.weth(), msg.sender, ethAmount, colAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP and COL balances and allowances to pay the debt
      * @dev Repays specified amount of debt paying fee in COL
      * @param asset The address of token using as main collateral
      * @param usdpAmount The amount of USDP token to repay
      * @param colPriceProof The merkle proof of the COL token price
      **/
    function repayUsingCol(
        address asset,
        uint usdpAmount,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        spawned(asset, msg.sender)
        nonReentrant
    {
        // check usefulness of tx
        require(usdpAmount != 0, "USDP: USELESS_TX");

        // COL token price in USD
        uint colUsdPrice_q112 = uniswapOracle.assetToUsd(vault.col(), 1, colPriceProof);

        uint fee = vault.calculateFee(asset, msg.sender, usdpAmount);
        uint feeInCol = fee.mul(Q112).div(colUsdPrice_q112);
        vault.chargeFee(vault.col(), msg.sender, feeInCol);
        vault.repay(asset, msg.sender, usdpAmount);

        // fire an event
        emit Exit(asset, msg.sender, 0, 0, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP and COL balances and allowances to pay the debt
      * @dev Withdraws collateral
      * @dev Repays specified amount of debt paying fee in COL
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      * @param mainPriceProof The merkle proof of the main collateral price
      * @param colPriceProof The merkle proof of the COL token price
      **/
    function withdrawAndRepayUsingCol(
        address asset,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory mainPriceProof,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        spawned(asset, msg.sender)
        nonReentrant
    {
        // check usefulness of tx
        require(mainAmount != 0 || colAmount != 0, "USDP: USELESS_TX");

        // fix 'Stack too deep'
        {
            uint debt = vault.debts(asset, msg.sender);
            require(debt != 0 && usdpAmount != debt, "USDP: USE_REPAY_ALL_INSTEAD");

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
        uint mainUsdValue_q112 = uniswapOracle.assetToUsd(asset, vault.collaterals(asset, msg.sender), mainPriceProof);

        // COL token value of the position in USD
        uint colUsdValue_q112 = uniswapOracle.assetToUsd(vault.col(), colDeposit, colPriceProof);

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

    /**
      * @notice Tx sender must have a sufficient USDP and COL balances to pay the debt
      * @dev Withdraws collateral converting WETH to ETH
      * @dev Repays specified amount of debt paying fee in COL
      * @param ethAmount The amount of ETH to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      * @param colPriceProof The merkle proof of the COL token price
      **/
    function withdrawAndRepayUsingCol_Eth(
        uint ethAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory mainPriceProof,
        UniswapOracle.ProofData memory colPriceProof
    )
        public
        spawned(vault.weth(), msg.sender)
        nonReentrant
    {
        // fix 'Stack too deep'
        {
            // check usefulness of tx
            require(ethAmount != 0 || colAmount != 0, "USDP: USELESS_TX");

            uint debt = vault.debts(vault.weth(), msg.sender);
            require(debt != 0 && usdpAmount != debt, "USDP: USE_REPAY_ALL_INSTEAD");

            if (ethAmount != 0) {
                // withdraw main collateral to the user address
                vault.withdrawEth(msg.sender, ethAmount);
            }

            if (colAmount != 0) {
                // withdraw COL tokens to the user's address
                vault.withdrawCol(vault.weth(), msg.sender, colAmount);
            }
        }

        uint colDeposit = vault.colToken(vault.weth(), msg.sender);

        // main collateral value of the position in USD
        uint mainUsdValue_q112 = uniswapOracle.assetToUsd(vault.weth(), vault.collaterals(vault.weth(), msg.sender), mainPriceProof);

        // COL token value of the position in USD
        uint colUsdValue_q112 = uniswapOracle.assetToUsd(vault.col(), colDeposit, colPriceProof);

        if (usdpAmount != 0) {
            uint fee = vault.calculateFee(vault.weth(), msg.sender, usdpAmount);
            uint feeInCol = fee.mul(Q112).mul(colDeposit).div(colUsdValue_q112);
            vault.chargeFee(vault.col(), msg.sender, feeInCol);
            vault.repay(vault.weth(), msg.sender, usdpAmount);
        }

        vault.update(vault.weth(), msg.sender);

        _ensureCollateralization(vault.weth(), msg.sender, mainUsdValue_q112, colUsdValue_q112);

        // fire an event
        emit Exit(vault.weth(), msg.sender, ethAmount, colAmount, usdpAmount);
    }

    function _depositAndBorrow(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory mainPriceProof,
        UniswapOracle.ProofData memory colPriceProof
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
        _ensureCollateralizationTroughProofs(asset, user, mainPriceProof, colPriceProof);
    }

    function _depositAndBorrow_Eth(
        address user,
        uint colAmount,
        uint usdpAmount,
        UniswapOracle.ProofData memory colPriceProof
    )
        internal
    {
        if (msg.value != 0) {
            vault.depositEth{value:msg.value}(user);
        }

        if (colAmount != 0) {
            vault.depositCol(vault.weth(), user, colAmount);
        }

        // mint USDP to user
        vault.borrow(vault.weth(), user, usdpAmount);

        _ensureCollateralizationTroughProofs_Eth(user, colPriceProof);
    }

    function _ensureCollateralizationTroughProofs(
        address asset,
        address user,
        UniswapOracle.ProofData memory mainPriceProof,
        UniswapOracle.ProofData memory colPriceProof
    )
        internal
        view
    {
        // main collateral value of the position in USD
        uint mainUsdValue_q112 = uniswapOracle.assetToUsd(asset, vault.collaterals(asset, user), mainPriceProof);

        // COL token value of the position in USD
        uint colUsdValue_q112 = uniswapOracle.assetToUsd(vault.col(), vault.colToken(asset, user), colPriceProof);

        _ensureCollateralization(asset, user, mainUsdValue_q112, colUsdValue_q112);
    }

    function _ensureCollateralizationTroughProofs_Eth(
        address user,
        UniswapOracle.ProofData memory colPriceProof
    )
        internal
        view
    {
        // ETH value of the position in USD
        uint ethUsdValue_q112 = uniswapOracle.ethToUsd(vault.collaterals(vault.weth(), user).mul(Q112));

        // COL token value of the position in USD
        uint colUsdValue_q112 = uniswapOracle.assetToUsd(vault.col(), vault.colToken(vault.weth(), user), colPriceProof);

        _ensureCollateralization(vault.weth(), user, ethUsdValue_q112, colUsdValue_q112);
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
        if (minColPercent != 0) {
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
        ) / Q112 / 100;

        // revert if collateralization is not enough
        require(vault.getTotalDebt(asset, user) <= usdLimit, "USDP: UNDERCOLLATERALIZED");
    }
}
