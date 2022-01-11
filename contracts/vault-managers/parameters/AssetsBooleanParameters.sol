// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../../Auth2.sol";
import "../../interfaces/vault-managers/parameters/IAssetsBooleanParameters.sol";


/**
 * @title AssetsBooleanParameters
 **/
contract AssetsBooleanParameters is Auth2, IAssetsBooleanParameters {

    mapping(address => uint256) internal values;

    constructor(address _vaultParameters, address[] memory _initialAssets, uint8[] memory _initialParams) Auth2(_vaultParameters) {
        require(_initialAssets.length == _initialParams.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");

        for (uint i = 0; i < _initialAssets.length; i++) {
            _set(_initialAssets[i], _initialParams[i], true);
        }
    }

    /**
     * @notice Get value of _param for _asset
     * @dev see ParametersConstants
     **/
    function get(address _asset, uint8 _param) external override view returns (bool) {
        return values[_asset] & (1 << _param) != 0;
    }

    /**
     * @notice Get values of all params for _asset. The 0th bit of returned uint id the value of param=0, etc
     **/
    function getAll(address _asset) external override view returns (uint256) {
        return values[_asset];
    }

    /**
     * @notice Set value of _param for _asset
     * @dev see ParametersConstants
     **/
    function set(address _asset, uint8 _param, bool _value) public override onlyManager {
        _set(_asset, _param, _value);
    }

    function _set(address _asset, uint8 _param, bool _value) internal {
        require(_asset != address(0), "Unit Protocol: ZERO_ADDRESS");

        if (_value) {
            values[_asset] |= (1 << _param);
            ValueSet(_asset, _param, values[_asset]);
        } else {
            values[_asset] &= ~(1 << _param);
            ValueUnset(_asset, _param, values[_asset]);
        }
    }
}
