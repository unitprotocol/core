// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

import "./IOracleUsd.sol";
import "./IOracleRegistry.sol";

interface IBearingAssetOracle is IOracleUsd {
    function bearingToUnderlying ( address bearing, uint256 amount ) external view returns ( address, uint256 );
    function oracleRegistry (  ) external view returns ( IOracleRegistry );
    function setUnderlying ( address bearing, address underlying ) external;
}
