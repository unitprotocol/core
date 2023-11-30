// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title ICurveRegistry
 * @dev Interface for interacting with the Curve Registry to fetch pool information.
 */
interface ICurveRegistry {

    /**
     * @dev Given an LP token address, returns the corresponding Curve pool address.
     * @param lpToken The address of the liquidity provider token.
     * @return The address of the Curve pool.
     */
    function get_pool_from_lp_token(address lpToken) external view returns (address);

    /**
     * @dev Given a Curve pool address, returns the number of coins the pool supports.
     * @param pool The address of the Curve pool.
     * @return An array where the first element is the number of coins in the pool, and the second element is 0.
     */
    function get_n_coins(address pool) external view returns (uint[2] memory);
}