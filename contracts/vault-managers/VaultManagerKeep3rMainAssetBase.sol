// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "../Vault.sol";
import "../helpers/Math.sol";
import "../helpers/ReentrancyGuard.sol";
import "./VaultManagerParameters.sol";
import "../oracles/OracleSimple.sol";


/**
 * @title VaultManagerKeep3rMainAssetBase
 **/
contract VaultManagerKeep3rMainAssetBase is ReentrancyGuard {
    using SafeMath for uint;

    Vault public immutable vault;
    VaultManagerParameters public immutable vaultManagerParameters;
    ChainlinkedOracleSimple public immutable oracle;
    uint public immutable ORACLE_TYPE;
    uint public constant Q112 = 2 ** 112;

    /**
     * @dev Trigger when joins are happened
    **/
    event Join(address indexed asset, address indexed user, uint main, uint usdp);

    /**
     * @dev Trigger when exits are happened
    **/
    event Exit(address indexed asset, address indexed user, uint main, uint usdp);

    modifier spawned(address asset, address user) {

        // check the existence of a position
        require(vault.getTotalDebt(asset, user) != 0, "Unit Protocol: NOT_SPAWNED_POSITION");
        require(vault.oracleType(asset, user) == ORACLE_TYPE, "Unit Protocol: WRONG_ORACLE_TYPE");
        _;
    }

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _keep3rOracleMainAsset The address of Keep3r-based Oracle for main asset
     * @param _oracleType The oracle type ID
     **/
    constructor(address _vaultManagerParameters, address _keep3rOracleMainAsset, uint _oracleType) public {
        vaultManagerParameters = VaultManagerParameters(_vaultManagerParameters);
        vault = Vault(VaultManagerParameters(_vaultManagerParameters).vaultParameters().vault());
        oracle = ChainlinkedOracleSimple(_keep3rOracleMainAsset);
        ORACLE_TYPE = _oracleType;
    }

    /**
      * @notice Cannot be used for already spawned positions
      * @notice Token using as main collateral must be whitelisted
      * @notice Depositing tokens must be pre-approved to vault address
      * @notice position actually considered as spawned only when usdpAmount > 0
      * @dev Spawns new positions
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function spawn(address asset, uint mainAmount, uint usdpAmount) public nonReentrant {
        require(usdpAmount != 0, "Unit Protocol: ZERO_BORROWING");

        // check whether the position is spawned
        require(vault.getTotalDebt(asset, msg.sender) == 0, "Unit Protocol: SPAWNED_POSITION");

        // oracle availability check
        require(vault.vaultParameters().isOracleTypeEnabled(ORACLE_TYPE, asset), "Unit Protocol: WRONG_ORACLE_TYPE");

        // USDP minting triggers the spawn of a position
        vault.spawn(asset, msg.sender, ORACLE_TYPE);

        _depositAndBorrow(asset, msg.sender, mainAmount, usdpAmount);

        // fire an event
        emit Join(asset, msg.sender, mainAmount, usdpAmount);
    }

    /**
      * @notice Cannot be used for already spawned positions
      * @notice WETH must be whitelisted as collateral
      * @notice position actually considered as spawned only when usdpAmount > 0
      * @dev Spawns new positions using ETH
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function spawn_Eth(uint usdpAmount) public payable nonReentrant {
        require(usdpAmount != 0, "Unit Protocol: ZERO_BORROWING");

        // check whether the position is spawned
        require(vault.getTotalDebt(vault.weth(), msg.sender) == 0, "Unit Protocol: SPAWNED_POSITION");

        // oracle availability check
        require(vault.vaultParameters().isOracleTypeEnabled(ORACLE_TYPE, vault.weth()), "Unit Protocol: WRONG_ORACLE_TYPE");

        // USDP minting triggers the spawn of a position
        vault.spawn(vault.weth(), msg.sender, ORACLE_TYPE);

        _depositAndBorrow_Eth(msg.sender, usdpAmount);

        // fire an event
        emit Join(vault.weth(), msg.sender, msg.value, usdpAmount);
    }

    /**
     * @notice Position should be spawned (USDP borrowed from position) to call this method
     * @notice Depositing tokens must be pre-approved to vault address
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals and borrows USDP to spawned positions simultaneously
     * @param asset The address of token using as main collateral
     * @param mainAmount The amount of main collateral to deposit
     * @param usdpAmount The amount of USDP token to borrow
     **/
    function depositAndBorrow(
        address asset,
        uint mainAmount,
        uint usdpAmount
    )
    public
    spawned(asset, msg.sender)
    nonReentrant
    {
        require(usdpAmount != 0, "Unit Protocol: ZERO_BORROWING");

        _depositAndBorrow(asset, msg.sender, mainAmount, usdpAmount);

        // fire an event
        emit Join(asset, msg.sender, mainAmount, usdpAmount);
    }

    /**
     * @notice Position should be spawned (USDP borrowed from position) to call this method
     * @notice Depositing tokens must be pre-approved to vault address
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals and borrows USDP to spawned positions simultaneously
     * @param usdpAmount The amount of USDP token to borrow
     **/
    function depositAndBorrow_Eth(uint usdpAmount) public payable spawned(vault.weth(), msg.sender) nonReentrant {
        require(usdpAmount != 0, "Unit Protocol: ZERO_BORROWING");

        _depositAndBorrow_Eth(msg.sender, usdpAmount);

        // fire an event
        emit Join(vault.weth(), msg.sender, msg.value, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral and repays specified amount of debt simultaneously
      * @param asset The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function withdrawAndRepay(
        address asset,
        uint mainAmount,
        uint usdpAmount
    )
    public
    spawned(asset, msg.sender)
    nonReentrant
    {
        // check usefulness of tx
        require(mainAmount != 0, "Unit Protocol: USELESS_TX");

        uint debt = vault.debts(asset, msg.sender);
        require(debt != 0 && usdpAmount != debt, "Unit Protocol: USE_REPAY_ALL_INSTEAD");

        // withdraw main collateral to the user address
        vault.withdrawMain(asset, msg.sender, mainAmount);

        if (usdpAmount != 0) {
            uint fee = vault.calculateFee(asset, msg.sender, usdpAmount);
            vault.chargeFee(vault.usdp(), msg.sender, fee);
            vault.repay(asset, msg.sender, usdpAmount);
        }

        vault.update(asset, msg.sender);

        _ensurePositionCollateralization(asset, msg.sender);

        // fire an event
        emit Exit(asset, msg.sender, mainAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral and repays specified amount of debt simultaneously converting WETH to ETH
      * @param ethAmount The amount of ETH to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function withdrawAndRepay_Eth(
        uint ethAmount,
        uint usdpAmount
    )
    public
    spawned(vault.weth(), msg.sender)
    nonReentrant
    {
        // check usefulness of tx
        require(ethAmount != 0, "Unit Protocol: USELESS_TX");

        uint debt = vault.debts(vault.weth(), msg.sender);
        require(debt != 0 && usdpAmount != debt, "Unit Protocol: USE_REPAY_ALL_INSTEAD");

        // withdraw main collateral to the user address
        vault.withdrawEth(msg.sender, ethAmount);

        if (usdpAmount != 0) {
            uint fee = vault.calculateFee(vault.weth(), msg.sender, usdpAmount);
            vault.chargeFee(vault.usdp(), msg.sender, fee);
            vault.repay(vault.weth(), msg.sender, usdpAmount);
        }

        vault.update(vault.weth(), msg.sender);

        _ensurePositionCollateralization_Eth(msg.sender);

        // fire an event
        emit Exit(vault.weth(), msg.sender, ethAmount, usdpAmount);
    }

    function _depositAndBorrow(
        address asset,
        address user,
        uint mainAmount,
        uint usdpAmount
    )
    internal
    {
        if (mainAmount != 0) {
            vault.depositMain(asset, user, mainAmount);
        }

        // mint USDP to user
        vault.borrow(asset, user, usdpAmount);

        // check collateralization
        _ensurePositionCollateralization(asset, user);
    }

    function _depositAndBorrow_Eth(address user, uint usdpAmount) internal {
        if (msg.value != 0) {
            vault.depositEth{value:msg.value}(user);
        }

        // mint USDP to user
        vault.borrow(vault.weth(), user, usdpAmount);

        _ensurePositionCollateralization_Eth(user);
    }

    function _ensurePositionCollateralization(
        address asset,
        address user
    )
    internal
    view
    {
        // main collateral value of the position in USD
        uint mainUsdValue_q112 = oracle.assetToUsd(asset, vault.collaterals(asset, user));

        _ensureCollateralization(asset, user, mainUsdValue_q112);
    }

    function _ensurePositionCollateralization_Eth(address user) internal view {
        // ETH value of the position in USD
        uint ethUsdValue_q112 = oracle.ethToUsd(vault.collaterals(vault.weth(), user).mul(Q112));

        _ensureCollateralization(vault.weth(), user, ethUsdValue_q112);
    }

    // ensures that borrowed value is in desired range
    function _ensureCollateralization(
        address asset,
        address user,
        uint mainUsdValue_q112
    )
    internal
    view
    {
        // USD limit of the position
        uint usdLimit = mainUsdValue_q112 * vaultManagerParameters.initialCollateralRatio(asset) / Q112 / 100;

        // revert if collateralization is not enough
        require(vault.getTotalDebt(asset, user) <= usdLimit, "Unit Protocol: UNDERCOLLATERALIZED");
    }
}
