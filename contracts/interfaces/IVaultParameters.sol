// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IVaultParameters
 * @dev Interface for interacting with Vault parameters.
 */
interface IVaultParameters {

    /**
     * @notice Check if an address has permission to modify the vault.
     * @param who The address to check.
     * @return True if the address has modification permissions, false otherwise.
     */
    function canModifyVault(address who) external view returns (bool);

    /**
     * @notice Get the foundation address.
     * @return The foundation address.
     */
    function foundation() external view returns (address);

    /**
     * @notice Check if an address is a manager.
     * @param who The address to check.
     * @return True if the address is a manager, false otherwise.
     */
    function isManager(address who) external view returns (bool);

    /**
     * @notice Check if an oracle type is enabled for a specific asset.
     * @param _type The oracle type identifier.
     * @param asset The address of the asset.
     * @return True if the oracle type is enabled, false otherwise.
     */
    function isOracleTypeEnabled(uint256 _type, address asset) external view returns (bool);

    /**
     * @notice Get the liquidation fee for a specific asset.
     * @param asset The address of the asset.
     * @return The liquidation fee as a percentage.
     */
    function liquidationFee(address asset) external view returns (uint256);

    /**
     * @notice Set collateral parameters for a specific asset.
     * @param asset The address of the asset.
     * @param stabilityFeeValue The stability fee as a percentage.
     * @param liquidationFeeValue The liquidation fee as a percentage.
     * @param usdpLimit The USDP limit for the asset.
     * @param oracles The array of oracle addresses.
     */
    function setCollateral(address asset, uint256 stabilityFeeValue, uint256 liquidationFeeValue, uint256 usdpLimit, uint256[] calldata oracles) external;

    /**
     * @notice Set the foundation address.
     * @param newFoundation The new foundation address.
     */
    function setFoundation(address newFoundation) external;

    /**
     * @notice Set the liquidation fee for a specific asset.
     * @param asset The address of the asset.
     * @param newValue The new liquidation fee as a percentage.
     */
    function setLiquidationFee(address asset, uint256 newValue) external;

    /**
     * @notice Set or unset an address as a manager.
     * @param who The address to set or unset as a manager.
     * @param permit True to set as a manager, false to unset.
     */
    function setManager(address who, bool permit) external;

    /**
     * @notice Enable or disable an oracle type for a specific asset.
     * @param _type The oracle type identifier.
     * @param asset The address of the asset.
     * @param enabled True to enable, false to disable the oracle type.
     */
    function setOracleType(uint256 _type, address asset, bool enabled) external;

    /**
     * @notice Set the stability fee for a specific asset.
     * @param asset The address of the asset.
     * @param newValue The new stability fee as a percentage.
     */
    function setStabilityFee(address asset, uint256 newValue) external;

    /**
     * @notice Set the token debt limit for a specific asset.
     * @param asset The address of the asset.
     * @param limit The new debt limit.
     */
    function setTokenDebtLimit(address asset, uint256 limit) external;

    /**
     * @notice Set or unset vault access for an address.
     * @param who The address to set or unset vault access.
     * @param permit True to set access, false to unset.
     */
    function setVaultAccess(address who, bool permit) external;

    /**
     * @notice Get the stability fee for a specific asset.
     * @param asset The address of the asset.
     * @return The stability fee as a percentage.
     */
    function stabilityFee(address asset) external view returns (uint256);

    /**
     * @notice Get the token debt limit for a specific asset.
     * @param asset The address of the asset.
     * @return The debt limit.
     */
    function tokenDebtLimit(address asset) external view returns (uint256);

    /**
     * @notice Get the vault address.
     * @return The vault address.
     */
    function vault() external view returns (address);

    /**
     * @notice Get the vault parameters address.
     * @return The vault parameters address.
     */
    function vaultParameters() external view returns (address);
}