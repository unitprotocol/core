// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IBearingAssetOracle
 * @dev Interface for the bearing asset oracle which converts bearing asset amounts to USD and underlying assets.
 */
interface IBearingAssetOracle {

    /**
     * @notice Convert the amount of the bearing asset to its equivalent in USD.
     * @param bearing The address of the bearing asset.
     * @param amount The amount of the bearing asset to convert.
     * @return The equivalent amount in USD.
     */
    function assetToUsd(address bearing, uint256 amount) external view returns (uint256);

    /**
     * @notice Convert the amount of the bearing asset to its underlying asset and amount.
     * @param bearing The address of the bearing asset.
     * @param amount The amount of the bearing asset to convert.
     * @return The address of the underlying asset and the equivalent amount of the underlying asset.
     */
    function bearingToUnderlying(address bearing, uint256 amount) external view returns (address, uint256);

    /**
     * @notice Get the address of the oracle registry.
     * @return The address of the oracle registry.
     */
    function oracleRegistry() external view returns (address);

    /**
     * @notice Set the underlying asset for a given bearing asset.
     * @dev This function can only be called by authorized entities.
     * @param bearing The address of the bearing asset.
     * @param underlying The address of the underlying asset to set.
     */
    function setUnderlying(address bearing, address underlying) external;

    /**
     * @notice Get the address of the vault parameters.
     * @return The address of the vault parameters.
     */
    function vaultParameters() external view returns (address);
}