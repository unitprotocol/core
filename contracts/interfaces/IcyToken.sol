// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IcyToken interface
 * @dev Interface for cyToken contracts which are interest-bearing tokens representing deposits in the protocol.
 */
interface IcyToken {
    /**
     * @dev Returns the underlying asset address of the cyToken.
     * @return The address of the underlying asset.
     */
    function underlying() external view returns (address);

    /**
     * @dev Returns the address of the current implementation.
     * @return The address of the implementation contract.
     */
    function implementation() external view returns (address);

    /**
     * @dev Returns the number of decimal places of the cyToken.
     * @return The number of decimal places.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the current exchange rate of the cyToken, scaled by 1e18.
     * @return The current exchange rate, scaled by 1e18.
     */
    function exchangeRateStored() external view returns (uint);
}