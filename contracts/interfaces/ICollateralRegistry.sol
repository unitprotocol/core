// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title ICollateralRegistry
 * @dev Interface for the management of collateral assets within the system.
 */
interface ICollateralRegistry {

    /**
     * @dev Adds a new collateral asset to the registry.
     * @param asset The address of the collateral asset to add.
     */
    function addCollateral(address asset) external;

    /**
     * @dev Retrieves the ID of a collateral asset.
     * @param asset The address of the collateral asset.
     * @return The ID of the collateral asset.
     */
    function collateralId(address asset) external view returns (uint256);

    /**
     * @dev Retrieves the list of all collateral assets in the registry.
     * @return An array of addresses of the collateral assets.
     */
    function collaterals() external view returns (address[] memory);

    /**
     * @dev Removes a collateral asset from the registry.
     * @param asset The address of the collateral asset to remove.
     */
    function removeCollateral(address asset) external;

    /**
     * @dev Retrieves the address of the VaultParameters contract.
     * @return The address of the VaultParameters contract.
     */
    function vaultParameters() external view returns (address);

    /**
     * @dev Checks if an address is a collateral in the registry.
     * @param asset The address of the collateral asset to check.
     * @return True if the address is a collateral, false otherwise.
     */
    function isCollateral(address asset) external view returns (bool);

    /**
     * @dev Retrieves the address of a collateral by its ID.
     * @param id The ID of the collateral asset.
     * @return The address of the collateral asset.
     */
    function collateralList(uint id) external view returns (address);

    /**
     * @dev Retrieves the count of collateral assets in the registry.
     * @return The count of collateral assets.
     */
    function collateralsCount() external view returns (uint);
}