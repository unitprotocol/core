// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./vault-managers/VaultManagerParameters.sol";
import "./Vault.sol";
import "./oracles/BearingAssetOracleSimple.sol";


/**
 * @title ParametersBatchUpdater
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Ivan Zakharov (@34x4p08)
 **/
contract ParametersBatchUpdater is Auth {

    VaultManagerParameters public immutable vaultManagerParameters;
    BearingAssetOracleSimple public immutable bearingAssetOracle;
    OracleRegistry public immutable oracleRegistry;

    constructor(address _vaultManagerParameters, address _bearingAssetOracle) public Auth(address(VaultManagerParameters(_vaultManagerParameters).vaultParameters())) {
        require(_vaultManagerParameters != address(0) && _bearingAssetOracle != address(0), "Unit Protocol: ZERO_ADDRESS");
        vaultManagerParameters = VaultManagerParameters(_vaultManagerParameters);
        bearingAssetOracle = BearingAssetOracleSimple(_bearingAssetOracle);
        oracleRegistry = OracleRegistry(BearingAssetOracleSimple(_bearingAssetOracle).oracleRegistry());
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Grants and revokes manager's status
     * @param who The array of target addresses
     * @param permit The array of permission flags
     **/
    function setManagers(address[] calldata who, bool[] calldata permit) external onlyManager {
        require(who.length == permit.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < who.length; i++) {
            vaultParameters.setManager(who[i], permit[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets a permission for provided addresses to modify the Vault
     * @param who The array of target addresses
     * @param permit The array of permission flags
     **/
    function setVaultAccesses(address[] calldata who, bool[] calldata permit) external onlyManager {
        require(who.length == permit.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < who.length; i++) {
            vaultParameters.setVaultAccess(who[i], permit[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the percentage of the year stability fee for a particular collateral
     * @param assets The array of addresses of the main collateral tokens
     * @param newValues The array of stability fee percentages (3 decimals)
     **/
    function setStabilityFees(address[] calldata assets, uint[] calldata newValues) public onlyManager {
        require(assets.length == newValues.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setStabilityFee(assets[i], newValues[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the percentages of the liquidation fee for provided collaterals
     * @param assets The array of addresses of the main collateral tokens
     * @param newValues The array of liquidation fee percentages (0 decimals)
     **/
    function setLiquidationFees(address[] calldata assets, uint[] calldata newValues) public onlyManager {
        require(assets.length == newValues.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setLiquidationFee(assets[i], newValues[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Enables/disables oracle types
     * @param _types The array of types of the oracles
     * @param assets The array of addresses of the main collateral tokens
     * @param flags The array of control flags
     **/
    function setOracleTypes(uint[] calldata _types, address[] calldata assets, bool[] calldata flags) public onlyManager {
        require(_types.length == assets.length && _types.length == flags.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < _types.length; i++) {
            vaultParameters.setOracleType(_types[i], assets[i], flags[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets USDP limits for a provided collaterals
     * @param assets The addresses of the main collateral tokens
     * @param limits The borrow USDP limits
     **/
    function setTokenDebtLimits(address[] calldata assets, uint[] calldata limits) public onlyManager {
        require(assets.length == limits.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setTokenDebtLimit(assets[i], limits[i]);
        }
    }

    function changeOracleTypes(address[] calldata assets, address[] calldata users, uint[] calldata oracleTypes) public onlyManager {
        require(assets.length == users.length && assets.length == oracleTypes.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            Vault(vaultParameters.vault()).changeOracleType(assets[i], users[i], oracleTypes[i]);
        }
    }

    function setInitialCollateralRatios(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setInitialCollateralRatio(assets[i], values[i]);
        }
    }

    function setLiquidationRatios(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setLiquidationRatio(assets[i], values[i]);
        }
    }

    function setLiquidationDiscounts(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setLiquidationDiscount(assets[i], values[i]);
        }
    }

    function setDevaluationPeriods(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setDevaluationPeriod(assets[i], values[i]);
        }
    }

    function setOraclesInRegistry(address[] calldata assets, address[] calldata oracles, uint[] calldata oracleTypes) public onlyManager {
        require(assets.length == oracles.length && assets.length == oracleTypes.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            oracleRegistry.setOracle(assets[i], oracles[i], oracleTypes[i]);
        }
    }

    function setUnderlyings(address[] calldata bearings, address[] calldata underlyings) public onlyManager {
        require(bearings.length == underlyings.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < bearings.length; i++) {
            bearingAssetOracle.setUnderlying(bearings[i], underlyings[i]);
        }
    }
}
