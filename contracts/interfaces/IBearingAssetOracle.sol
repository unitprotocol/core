// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IBearingAssetOracle {
    function assetToUsd ( address bearing, uint256 amount ) external view returns ( uint256 );
    function bearingToUnderlying ( address bearing, uint256 amount ) external view returns ( address, uint256 );
    function oracleRegistry (  ) external view returns ( address );
    function setUnderlying ( address bearing, address underlying ) external;
    function vaultParameters (  ) external view returns ( address );
}
