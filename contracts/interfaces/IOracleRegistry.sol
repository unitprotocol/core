// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;
pragma abicoder v2;

/**
 * @title IOracleRegistry
 * @dev Interface for the Oracle Registry which manages oracles and their types.
 */
interface IOracleRegistry {

    /**
     * @dev Represents an Oracle with its type and address.
     */
    struct Oracle {
        uint oracleType;      // The type of the oracle
        address oracleAddress; // The address of the oracle
    }

    /**
     * @dev Returns the address of WETH token.
     * @return The WETH token address.
     */
    function WETH() external view returns (address);

    /**
     * @dev Returns an array of Keydonix oracle types.
     * @return An array of Keydonix oracle types.
     */
    function getKeydonixOracleTypes() external view returns (uint256[] memory);

    /**
     * @dev Returns an array of all oracles with their types.
     * @return foundOracles An array of Oracle struct containing oracle types and addresses.
     */
    function getOracles() external view returns (Oracle[] memory foundOracles);

    /**
     * @dev Returns a Keydonix oracle type by its index.
     * @param index The index of the Keydonix oracle type.
     * @return The Keydonix oracle type.
     */
    function keydonixOracleTypes(uint256 index) external view returns (uint256);

    /**
     * @dev Returns the maximum oracle type value.
     * @return The maximum oracle type value.
     */
    function maxOracleType() external view returns (uint256);

    /**
     * @dev Returns the oracle address for a given asset.
     * @param asset The address of the asset.
     * @return The oracle address.
     */
    function oracleByAsset(address asset) external view returns (address);

    /**
     * @dev Returns the oracle address for a given oracle type.
     * @param oracleType The oracle type.
     * @return The oracle address.
     */
    function oracleByType(uint256 oracleType) external view returns (address);

    /**
     * @dev Returns the oracle type for a given asset.
     * @param asset The address of the asset.
     * @return The oracle type.
     */
    function oracleTypeByAsset(address asset) external view returns (uint256);

    /**
     * @dev Returns the oracle type for a given oracle address.
     * @param oracle The address of the oracle.
     * @return The oracle type.
     */
    function oracleTypeByOracle(address oracle) external view returns (uint256);

    /**
     * @dev Sets the Keydonix oracle types.
     * @param _keydonixOracleTypes An array of new Keydonix oracle types.
     */
    function setKeydonixOracleTypes(uint256[] memory _keydonixOracleTypes) external;

    /**
     * @dev Sets an oracle with its type.
     * @param oracleType The oracle type.
     * @param oracle The oracle address.
     */
    function setOracle(uint256 oracleType, address oracle) external;

    /**
     * @dev Sets the oracle type for an asset.
     * @param asset The asset address.
     * @param oracleType The oracle type.
     */
    function setOracleTypeForAsset(address asset, uint256 oracleType) external;

    /**
     * @dev Sets the same oracle type for multiple assets.
     * @param assets An array of asset addresses.
     * @param oracleType The oracle type.
     */
    function setOracleTypeForAssets(address[] memory assets, uint256 oracleType) external;

    /**
     * @dev Unsets the oracle for a given oracle type.
     * @param oracleType The oracle type.
     */
    function unsetOracle(uint256 oracleType) external;

    /**
     * @dev Unsets the oracle for a given asset.
     * @param asset The asset address.
     */
    function unsetOracleForAsset(address asset) external;

    /**
     * @dev Unsets the oracles for multiple assets.
     * @param assets An array of asset addresses.
     */
    function unsetOracleForAssets(address[] memory assets) external;

    /**
     * @dev Returns the address of the vault parameters contract.
     * @return The address of the vault parameters contract.
     */
    function vaultParameters() external view returns (address);
}