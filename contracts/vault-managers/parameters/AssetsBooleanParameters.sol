// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../../Auth2.sol";
import "../../interfaces/vault-managers/parameters/IAssetsBooleanParameters.sol";

/* @title Manages boolean parameters for assets in the Unit Protocol system. */
contract AssetsBooleanParameters is Auth2, IAssetsBooleanParameters {

    mapping(address => uint256) internal values;

    /* 
      @notice Constructor to initialize the contract with initial assets and their parameters.
      @param _vaultParameters The address of the VaultParameters contract.
      @param _initialAssets Array of asset addresses to initialize.
      @param _initialParams Array of initial parameter values for each asset.
      @dev _initialAssets and _initialParams must be the same length.
      @dev Throws if the length of _initialAssets and _initialParams does not match.
    */
    constructor(address _vaultParameters, address[] memory _initialAssets, uint8[] memory _initialParams) Auth2(_vaultParameters) {
        require(_initialAssets.length == _initialParams.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");

        for (uint i = 0; i < _initialAssets.length; i++) {
            _set(_initialAssets[i], _initialParams[i], true);
        }
    }

    /* 
      @notice Retrieves the boolean value of a specified parameter for an asset.
      @param _asset The address of the asset.
      @param _param The parameter index to retrieve.
      @return The boolean value of the specified parameter for the given asset.
    */
    function get(address _asset, uint8 _param) external override view returns (bool) {
        return values[_asset] & (1 << _param) != 0;
    }

    /* 
      @notice Retrieves all parameter values for an asset as a single uint256.
      @param _asset The address of the asset.
      @return A uint256 representing all parameter values for the given asset.
    */
    function getAll(address _asset) external override view returns (uint256) {
        return values[_asset];
    }

    /* 
      @notice Sets the boolean value of a specified parameter for an asset.
      @param _asset The address of the asset.
      @param _param The parameter index to set.
      @param _value The boolean value to set for the specified parameter.
      @dev Emits a ValueSet or ValueUnset event upon success.
      @dev Only callable by the manager role.
    */
    function set(address _asset, uint8 _param, bool _value) public override onlyManager {
        _set(_asset, _param, _value);
    }

    /* 
      @notice Internal function to set the boolean value of a specified parameter for an asset.
      @param _asset The address of the asset.
      @param _param The parameter index to set.
      @param _value The boolean value to set for the specified parameter.
      @dev Emits a ValueSet or ValueUnset event upon success.
      @dev Throws if trying to set a value for the zero address.
    */
    function _set(address _asset, uint8 _param, bool _value) internal {
        require(_asset != address(0), "Unit Protocol: ZERO_ADDRESS");

        if (_value) {
            values[_asset] |= (1 << _param);
            emit ValueSet(_asset, _param, values[_asset]);
        } else {
            values[_asset] &= ~(1 << _param);
            emit ValueUnset(_asset, _param, values[_asset]);
        }
    }
}