// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title ICurveProvider
 * @dev Interface for interacting with the Curve protocol's provider contract.
 */
interface ICurveProvider {
    /**
     * @dev Returns the address of the Curve registry contract.
     * @return The address of the Curve registry.
     */
    function get_registry() external view returns (address);
}