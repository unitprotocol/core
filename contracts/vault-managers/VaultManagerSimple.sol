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
 * @title VaultManagerSimple
 * @notice Usage: `join` to join, `exit` to exit
 **/
contract VaultManagerSimple is ReentrancyGuard {
    using SafeMath for uint;

    Vault public immutable vault;
    VaultManagerParameters public immutable vaultManagerParameters;
    OracleSimple public immutable oracle;
    
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

    /**
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _oracle The address of an oracle
     * @param _oracleType The oracle type ID
     **/
    constructor(address _vaultManagerParameters, address _oracle, uint _oracleType) public {
        require(_vaultManagerParameters != address(0) && _oracle != address(0) && _oracleType != 0, "Unit Protocol: INVALID_ARGS");
        vaultManagerParameters = VaultManagerParameters(_vaultManagerParameters);
        vault = Vault(VaultManagerParameters(_vaultManagerParameters).vaultParameters().vault());
        oracle = OracleSimple(_oracle);
        ORACLE_TYPE = _oracleType;
    }

    /**
      * @notice Token using as main collateral must be whitelisted
      * @notice Depositing tokens must be pre-approved to Vault address
      * @notice position actually considered as spawned only when debt > 0
      * @dev Deposits collateral and/or borrows USDP
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function join(address asset, uint assetAmount, uint usdpAmount) public nonReentrant {
        require(usdpAmount != 0, "Unit Protocol: ZERO_BORROWING");

        bool spawned = vault.getTotalDebt(asset, msg.sender) != 0;

        // oracle availability check
        require(vault.vaultParameters().isOracleTypeEnabled(ORACLE_TYPE, asset), "Unit Protocol: WRONG_ORACLE_TYPE");

        if (spawned) {
            // check oracle type
            require(vault.oracleType(asset, msg.sender) == ORACLE_TYPE, "Unit Protocol: WRONG_ORACLE_TYPE");
        } else {
            // spawn a position
            vault.spawn(asset, msg.sender, ORACLE_TYPE);
        }

        if (assetAmount != 0) {
            vault.depositMain(asset, msg.sender, assetAmount);
        }

        // mint USDP to user
        vault.borrow(asset, msg.sender, usdpAmount);

        // check collateralization
        _ensurePositionCollateralization(asset, msg.sender);

        // fire an event
        emit Join(asset, msg.sender, assetAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral and repays specified amount of debt
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function exit(address asset, uint assetAmount, uint usdpAmount) public nonReentrant {
        
        // check usefulness of tx
        require(assetAmount != 0, "Unit Protocol: USELESS_TX");
        
        // check the existence of a position
        require(vault.getTotalDebt(asset, msg.sender) != 0, "Unit Protocol: NOT_SPAWNED_POSITION");
        
        // check oracle type
        require(vault.oracleType(asset, msg.sender) == ORACLE_TYPE, "Unit Protocol: WRONG_ORACLE_TYPE");

        uint debt = vault.debts(asset, msg.sender);
        require(debt != 0 && usdpAmount != debt, "Unit Protocol: USE_REPAY_ALL_INSTEAD");

        // withdraw collateral to the user address
        vault.withdrawMain(asset, msg.sender, assetAmount);

        if (usdpAmount != 0) {
            uint fee = vault.calculateFee(asset, msg.sender, usdpAmount);
            vault.chargeFee(vault.usdp(), msg.sender, fee);
            vault.repay(asset, msg.sender, usdpAmount);
        }

        vault.update(asset, msg.sender);

        _ensurePositionCollateralization(asset, msg.sender);

        // fire an event
        emit Exit(asset, msg.sender, assetAmount, usdpAmount);
    }

    function _ensurePositionCollateralization(address asset, address user) internal view {
        // main collateral value of the position in USD
        uint mainUsdValue_q112 = oracle.assetToUsd(asset, vault.collaterals(asset, user));

        // USD limit of the position
        uint usdLimit = mainUsdValue_q112 * vaultManagerParameters.initialCollateralRatio(asset) / Q112 / 100;

        // revert if collateralization is not enough
        require(vault.getTotalDebt(asset, user) <= usdLimit, "Unit Protocol: UNDERCOLLATERALIZED");
    }
}
