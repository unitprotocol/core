// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

/**
 * @title ICDPRegistry
 * @dev Interface for CDPRegistry, a contract that manages the registry of Collateralized Debt Positions (CDPs).
 */
interface ICDPRegistry {

    /**
     * @dev Represents a collateralized debt position (CDP).
     * @param asset The address of the collateral asset.
     * @param owner The address of the owner of the CDP.
     */
    struct CDP {
        address asset;
        address owner;
    }

    /**
     * @dev Registers a batch checkpoint for multiple CDPs.
     * @param assets Array of asset addresses corresponding to the CDPs.
     * @param owners Array of owner addresses corresponding to the CDPs.
     */
    function batchCheckpoint(address[] calldata assets, address[] calldata owners) external;

    /**
     * @dev Registers a batch checkpoint for a single asset and multiple owners.
     * @param asset The address of the asset for which to checkpoint.
     * @param owners Array of owner addresses corresponding to the CDPs.
     */
    function batchCheckpointForAsset(address asset, address[] calldata owners) external;

    /**
     * @dev Registers a checkpoint for a single CDP.
     * @param asset The address of the collateral asset.
     * @param owner The address of the owner of the CDP.
     */
    function checkpoint(address asset, address owner) external;

    /**
     * @dev Returns the address of the Collateral Ratio contract.
     * @return The address of the CR contract.
     */
    function cr() external view returns (address);

    /**
     * @dev Retrieves all CDPs in the registry.
     * @return r An array of all CDPs.
     */
    function getAllCdps() external view returns (CDP[] memory r);

    /**
     * @dev Retrieves all CDPs associated with a particular collateral asset.
     * @param asset The address of the collateral asset.
     * @return cdps An array of CDPs for the specified asset.
     */
    function getCdpsByCollateral(address asset) external view returns (CDP[] memory cdps);

    /**
     * @dev Retrieves all CDPs associated with a particular owner.
     * @param owner The address of the owner.
     * @return r An array of CDPs for the specified owner.
     */
    function getCdpsByOwner(address owner) external view returns (CDP[] memory r);

    /**
     * @dev Returns the total count of CDPs in the registry.
     * @return totalCdpCount The total number of CDPs.
     */
    function getCdpsCount() external view returns (uint256 totalCdpCount);

    /**
     * @dev Returns the count of CDPs for a given collateral asset.
     * @param asset The address of the collateral asset.
     * @return The number of CDPs for the specified asset.
     */
    function getCdpsCountForCollateral(address asset) external view returns (uint256);

    /**
     * @dev Checks if a CDP is alive (active and not closed).
     * @param asset The address of the collateral asset.
     * @param owner The address of the owner of the CDP.
     * @return True if the CDP is alive, false otherwise.
     */
    function isAlive(address asset, address owner) external view returns (bool);

    /**
     * @dev Checks if a CDP is listed in the registry.
     * @param asset The address of the collateral asset.
     * @param owner The address of the owner of the CDP.
     * @return True if the CDP is listed, false otherwise.
     */
    function isListed(address asset, address owner) external view returns (bool);

    /**
     * @dev Returns the address of the vault contract.
     * @return The address of the vault contract.
     */
    function vault() external view returns (address);
}