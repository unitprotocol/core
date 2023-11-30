// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title Interface for WrappedToUnderlyingOracle
 * @dev Interface for the service that provides mappings from wrapped tokens to their underlying assets.
 */
interface IWrappedToUnderlyingOracle {
    
    /**
     * @notice Retrieves the underlying asset address for a given wrapped token address.
     * @param wrappedToken The address of the wrapped token contract.
     * @return The address of the underlying asset.
     */
    function assetToUnderlying(address wrappedToken) external view returns (address);
}