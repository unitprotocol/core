// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IcyToken {
    function underlying() external view returns (address);
    function implementation() external view returns (address);
    function decimals() external view returns (uint8);
    function exchangeRateStored() external view returns (uint);
}
