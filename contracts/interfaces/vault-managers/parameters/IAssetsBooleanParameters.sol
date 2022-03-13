// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IAssetsBooleanParameters {

    event ValueSet(address indexed asset, uint8 param, uint256 valuesForAsset);
    event ValueUnset(address indexed asset, uint8 param, uint256 valuesForAsset);

    function get(address _asset, uint8 _param) external view returns (bool);
    function getAll(address _asset) external view returns (uint256);
    function set(address _asset, uint8 _param, bool _value) external;
}
