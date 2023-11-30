// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IOracleUsd
 * @dev Interface for Oracle that provides USD price for an asset.
 */
interface IOracleUsd {

    /**
     * @notice Converts asset amount to USD price.
     * @param asset The address of the asset.
     * @param amount The amount of the asset to convert.
     * @return The USD price of the given asset amount, encoded in Q112 format (10**18 * 2**112 is $1).
     */
    function assetToUsd(address asset, uint amount) external view returns (uint);
}