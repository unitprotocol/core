// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IyvToken {
    function token() external view returns (address);
    function decimals() external view returns (uint256);
    function pricePerShare() external view returns (uint256);
    function emergencyShutdown() external view returns (bool);
}
