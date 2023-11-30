// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IAssetsBooleanParameters
 * @dev Interface for setting and getting boolean parameters of assets.
 */
interface IAssetsBooleanParameters {

    /**
     * @dev Emitted when a boolean parameter value is set for an asset.
     * @param asset The address of the asset.
     * @param param The parameter index being set.
     * @param valuesForAsset The new parameter value for the asset.
     */
    event ValueSet(address indexed asset, uint8 param, uint256 valuesForAsset);

    /**
     * @dev Emitted when a boolean parameter value is unset for an asset.
     * @param asset The address of the asset.
     * @param param The parameter index being unset.
     * @param valuesForAsset The previous parameter value for the asset.
     */
    event ValueUnset(address indexed asset, uint8 param, uint256 valuesForAsset);

    /**
     * @notice Retrieves the boolean parameter value for a given asset and parameter index.
     * @param _asset The address of the asset.
     * @param _param The index of the parameter.
     * @return The boolean value of the parameter.
     */
    function get(address _asset, uint8 _param) external view returns (bool);

    /**
     * @notice Retrieves all boolean parameter values for a given asset.
     * @param _asset The address of the asset.
     * @return The uint256 representation of all boolean parameters for the asset.
     */
    function getAll(address _asset) external view returns (uint256);

    /**
     * @notice Sets the boolean parameter value for a given asset.
     * @param _asset The address of the asset.
     * @param _param The index of the parameter to set.
     * @param _value The boolean value to set for the parameter.
     */
    function set(address _asset, uint8 _param, bool _value) external;
}