// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IVaultManagerParameters
 * @dev Interface for interacting with Vault Manager Parameters in Unit Protocol.
 */
interface IVaultManagerParameters {
    /**
     * @notice Gets the devaluation period of a collateral asset.
     * @param asset The address of the collateral asset.
     * @return The devaluation period in seconds.
     */
    function devaluationPeriod(address asset) external view returns (uint256);

    /**
     * @notice Gets the initial collateral ratio for a collateral asset.
     * @param asset The address of the collateral asset.
     * @return The initial collateral ratio in percentage.
     */
    function initialCollateralRatio(address asset) external view returns (uint256);

    /**
     * @notice Gets the liquidation discount for a collateral asset.
     * @param asset The address of the collateral asset.
     * @return The liquidation discount in percentage.
     */
    function liquidationDiscount(address asset) external view returns (uint256);

    /**
     * @notice Gets the liquidation ratio for a collateral asset.
     * @param asset The address of the collateral asset.
     * @return The liquidation ratio in percentage.
     */
    function liquidationRatio(address asset) external view returns (uint256);

    /**
     * @notice Gets the maximum collateral percentage for a collateral asset.
     * @param asset The address of the collateral asset.
     * @return The maximum collateral percentage in percentage.
     */
    function maxColPercent(address asset) external view returns (uint256);

    /**
     * @notice Gets the minimum collateral percentage for a collateral asset.
     * @param asset The address of the collateral asset.
     * @return The minimum collateral percentage in percentage.
     */
    function minColPercent(address asset) external view returns (uint256);

    /**
     * @notice Sets the collateral percentage range for a given asset.
     * @param asset The address of the collateral asset.
     * @param min The minimum collateral percentage.
     * @param max The maximum collateral percentage.
     */
    function setColPartRange(address asset, uint256 min, uint256 max) external;

    /**
     * @notice Sets various parameters for a collateral asset.
     * @param asset The address of the collateral asset.
     * @param stabilityFeeValue The stability fee value.
     * @param liquidationFeeValue The liquidation fee value.
     * @param initialCollateralRatioValue The initial collateral ratio value.
     * @param liquidationRatioValue The liquidation ratio value.
     * @param liquidationDiscountValue The liquidation discount value.
     * @param devaluationPeriodValue The devaluation period value in seconds.
     * @param usdpLimit The USDP limit for this collateral.
     * @param oracles The array of oracle addresses.
     * @param minColP The minimum collateral percentage.
     * @param maxColP The maximum collateral percentage.
     */
    function setCollateral(
        address asset,
        uint256 stabilityFeeValue,
        uint256 liquidationFeeValue,
        uint256 initialCollateralRatioValue,
        uint256 liquidationRatioValue,
        uint256 liquidationDiscountValue,
        uint256 devaluationPeriodValue,
        uint256 usdpLimit,
        uint256[] calldata oracles,
        uint256 minColP,
        uint256 maxColP
    ) external;

    /**
     * @notice Sets the devaluation period for a collateral asset.
     * @param asset The address of the collateral asset.
     * @param newValue The new devaluation period in seconds.
     */
    function setDevaluationPeriod(address asset, uint256 newValue) external;

    /**
     * @notice Sets the initial collateral ratio for a collateral asset.
     * @param asset The address of the collateral asset.
     * @param newValue The new initial collateral ratio in percentage.
     */
    function setInitialCollateralRatio(address asset, uint256 newValue) external;

    /**
     * @notice Sets the liquidation discount for a collateral asset.
     * @param asset The address of the collateral asset.
     * @param newValue The new liquidation discount in percentage.
     */
    function setLiquidationDiscount(address asset, uint256 newValue) external;

    /**
     * @notice Sets the liquidation ratio for a collateral asset.
     * @param asset The address of the collateral asset.
     * @param newValue The new liquidation ratio in percentage.
     */
    function setLiquidationRatio(address asset, uint256 newValue) external;

    /**
     * @notice Gets the address of the vault parameters contract.
     * @return The address of the vault parameters contract.
     */
    function vaultParameters() external view returns (address);
}