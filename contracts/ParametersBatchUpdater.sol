// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma abicoder v2;

import "./VaultParameters.sol";
import "./interfaces/vault-managers/parameters/IVaultManagerParameters.sol";
import "./interfaces/IBearingAssetOracle.sol";
import "./interfaces/IOracleRegistry.sol";
import "./interfaces/ICollateralRegistry.sol";
import "./interfaces/IVault.sol";

/* 
 * Contract for batch updating parameters related to vaults.
 */
contract ParametersBatchUpdater is Auth {

    IVaultManagerParameters public immutable vaultManagerParameters;
    IOracleRegistry public immutable oracleRegistry;
    ICollateralRegistry public immutable collateralRegistry;

    uint public constant BEARING_ASSET_ORACLE_TYPE = 9;

    /* 
     * Sets vault manager parameters, oracle registry, and collateral registry.
     * @param _vaultManagerParameters The address of the vault manager parameters contract.
     * @param _oracleRegistry The address of the oracle registry contract.
     * @param _collateralRegistry The address of the collateral registry contract.
     */
    constructor(
        address _vaultManagerParameters,
        address _oracleRegistry,
        address _collateralRegistry
    ) Auth(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()) {
        require(
            _vaultManagerParameters != address(0) &&
            _oracleRegistry != address(0) &&
            _collateralRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        vaultManagerParameters = IVaultManagerParameters(_vaultManagerParameters);
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        collateralRegistry = ICollateralRegistry(_collateralRegistry);
    }

    /* 
     * Updates manager status for multiple addresses.
     * @param who The addresses to update.
     * @param permit The manager statuses to set.
     */
    function setManagers(address[] calldata who, bool[] calldata permit) external onlyManager {
        require(who.length == permit.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < who.length; i++) {
            vaultParameters.setManager(who[i], permit[i]);
        }
    }

    /* 
     * Updates Vault access permissions for multiple addresses.
     * @param who The addresses to update.
     * @param permit The access permissions to set.
     */
    function setVaultAccesses(address[] calldata who, bool[] calldata permit) external onlyManager {
        require(who.length == permit.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < who.length; i++) {
            vaultParameters.setVaultAccess(who[i], permit[i]);
        }
    }

    /* 
     * Updates the stability fee for multiple collaterals.
     * @param assets The collateral tokens to update.
     * @param newValues The stability fees to set.
     */
    function setStabilityFees(address[] calldata assets, uint[] calldata newValues) public onlyManager {
        require(assets.length == newValues.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setStabilityFee(assets[i], newValues[i]);
        }
    }

    /* 
     * Updates the liquidation fee for multiple collaterals.
     * @param assets The collateral tokens to update.
     * @param newValues The liquidation fees to set.
     */
    function setLiquidationFees(address[] calldata assets, uint[] calldata newValues) public onlyManager {
        require(assets.length == newValues.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setLiquidationFee(assets[i], newValues[i]);
        }
    }

    /* 
     * Enables or disables oracle types for multiple collaterals.
     * @param _types The oracle types to update.
     * @param assets The collateral tokens to update.
     * @param flags The enablement statuses to set.
     */
    function setOracleTypes(uint[] calldata _types, address[] calldata assets, bool[] calldata flags) public onlyManager {
        require(_types.length == assets.length && _types.length == flags.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < _types.length; i++) {
            vaultParameters.setOracleType(_types[i], assets[i], flags[i]);
        }
    }

    /* 
     * Updates the USDP borrow limits for multiple collaterals.
     * @param assets The collateral tokens to update.
     * @param limits The USDP borrow limits to set.
     */
    function setTokenDebtLimits(address[] calldata assets, uint[] calldata limits) public onlyManager {
        require(assets.length == limits.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setTokenDebtLimit(assets[i], limits[i]);
        }
    }

    /* 
     * Changes the oracle types for multiple collaterals and users.
     * @param assets The collateral tokens to update.
     * @param users The user addresses to update.
     * @param oracleTypes The new oracle types to set.
     */
    function changeOracleTypes(address[] calldata assets, address[] calldata users, uint[] calldata oracleTypes) public onlyManager {
        require(assets.length == users.length && assets.length == oracleTypes.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            IVault(vaultParameters.vault()).changeOracleType(assets[i], users[i], oracleTypes[i]);
        }
    }

    /* 
     * Updates the initial collateral ratios for multiple collaterals.
     * @param assets The collateral tokens to update.
     * @param values The initial collateral ratios to set.
     */
    function setInitialCollateralRatios(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setInitialCollateralRatio(assets[i], values[i]);
        }
    }

    /* 
     * Updates the liquidation ratios for multiple collaterals.
     * @param assets The collateral tokens to update.
     * @param values The liquidation ratios to set.
     */
    function setLiquidationRatios(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setLiquidationRatio(assets[i], values[i]);
        }
    }

    /* 
     * Updates the liquidation discounts for multiple collaterals.
     * @param assets The collateral tokens to update.
     * @param values The liquidation discounts to set.
     */
    function setLiquidationDiscounts(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setLiquidationDiscount(assets[i], values[i]);
        }
    }

    /* 
     * Updates the devaluation periods for multiple collaterals.
     * @param assets The collateral tokens to update.
     * @param values The devaluation periods to set.
     */
    function setDevaluationPeriods(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setDevaluationPeriod(assets[i], values[i]);
        }
    }

    /* 
     * Updates oracle types in the oracle registry for multiple oracles.
     * @param oracleTypes The oracle types to update.
     * @param oracles The oracle addresses to update.
     */
    function setOracleTypesInRegistry(uint[] calldata oracleTypes, address[] calldata oracles) public onlyManager {
        require(oracleTypes.length == oracles.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < oracleTypes.length; i++) {
            oracleRegistry.setOracle(oracleTypes[i], oracles[i]);
        }
    }

    /* 
     * Associates oracle types with multiple assets in the oracle registry.
     * @param assets The asset addresses to update.
     * @param oracleTypes The oracle types to associate.
     */
    function setOracleTypesToAssets(address[] calldata assets, uint[] calldata oracleTypes) public onlyManager {
        require(oracleTypes.length == assets.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            oracleRegistry.setOracleTypeForAsset(assets[i], oracleTypes[i]);
        }
    }

    /* 
     * Batch sets oracle types for arrays of assets in the oracle registry.
     * @param assets Array of arrays of asset addresses.
     * @param oracleTypes The oracle types to set.
     */
    function setOracleTypesToAssetsBatch(address[][] calldata assets, uint[] calldata oracleTypes) public onlyManager {
        require(oracleTypes.length == assets.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            oracleRegistry.setOracleTypeForAssets(assets[i], oracleTypes[i]);
        }
    }

    /* 
     * Sets the underlying assets for multiple bearing assets in the oracle registry.
     * @param bearings The bearing asset addresses to update.
     * @param underlyings The underlying asset addresses to set.
     */
    function setUnderlyings(address[] calldata bearings, address[] calldata underlyings) public onlyManager {
        require(bearings.length == underlyings.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < bearings.length; i++) {
            IBearingAssetOracle(oracleRegistry.oracleByType(BEARING_ASSET_ORACLE_TYPE)).setUnderlying(bearings[i], underlyings[i]);
        }
    }

    /* 
     * Sets multiple parameters for collateral assets.
     * @param assets The collateral asset addresses to update.
     * @param stabilityFeeValue The stability fee value for all assets.
     * @param liquidationFeeValue The liquidation fee value for all assets.
     * @param initialCollateralRatioValue The initial collateral ratio value for all assets.
     * @param liquidationRatioValue The liquidation ratio value for all assets.
     * @param liquidationDiscountValue The liquidation discount value for all assets.
     * @param devaluationPeriodValue The devaluation period value for all assets.
     * @param usdpLimit The USDP limit for all assets.
     * @param oracles The oracle addresses for all assets.
     */
    function setCollaterals(
        address[] calldata assets,
        uint stabilityFeeValue,
        uint liquidationFeeValue,
        uint initialCollateralRatioValue,
        uint liquidationRatioValue,
        uint liquidationDiscountValue,
        uint devaluationPeriodValue,
        uint usdpLimit,
        uint[] calldata oracles
    ) external onlyManager {
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setCollateral(
                assets[i],
                stabilityFeeValue,
                liquidationFeeValue,
                initialCollateralRatioValue,
                liquidationRatioValue,
                liquidationDiscountValue,
                devaluationPeriodValue,
                usdpLimit,
                oracles,
                0,
                0
            );

            collateralRegistry.addCollateral(assets[i]);
        }
    }

    /* 
     * Adds or removes collateral addresses in the collateral registry.
     * @param assets The collateral asset addresses to update.
     * @param add Whether to add (true) or remove (false) the addresses.
     */
    function setCollateralAddresses(address[] calldata assets, bool add) external onlyManager {
        for (uint i = 0; i < assets.length; i++) {
            add ? collateralRegistry.addCollateral(assets[i]) : collateralRegistry.removeCollateral(assets[i]);
        }
    }
}