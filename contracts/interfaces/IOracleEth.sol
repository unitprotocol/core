// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IOracleEth
 * @dev Interface for the ETH-based price oracle, providing conversion rates between assets and ETH, and ETH to USD.
 */
interface IOracleEth {

    /**
     * @dev Returns the Q112-encoded value of the asset in terms of ETH.
     * @param asset The address of the asset token contract.
     * @param amount The amount of the asset tokens to convert.
     * @return The equivalent amount of asset in ETH, encoded in Q112 format.
     * @notice The returned value scaled by 10**18 * 2**112 represents 1 Ether.
     */
    function assetToEth(address asset, uint amount) external view returns (uint);

    /**
     * @dev Returns the value of ETH in terms of USD.
     * @param amount The amount of ETH to convert.
     * @return The equivalent amount of ETH in USD, without any encoding.
     */
    function ethToUsd(uint amount) external view returns (uint);

    /**
     * @dev Returns the value of USD in terms of ETH.
     * @param amount The amount of USD to convert.
     * @return The equivalent amount of USD in ETH, without any encoding.
     */
    function usdToEth(uint amount) external view returns (uint);
}