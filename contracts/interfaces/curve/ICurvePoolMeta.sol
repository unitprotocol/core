// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

import "./ICurvePoolBase.sol";

/**
 * @title ICurvePoolMeta
 * @dev Interface for interacting with Curve's meta pools, which allow for interactions
 * with liquidity pools containing tokens and meta tokens (like 3CRV).
 */
interface ICurvePoolMeta is ICurvePoolBase {

    /**
     * @notice Get the address of the base pool contract
     * @dev Returns the contract address of the base pool associated with this meta pool
     * @return The address of the base pool contract
     */
    function base_pool() external view returns (address);

    /**
     * @notice Exchange an amount of one underlying coin for another in the pool
     * @dev This function allows for an exchange between two underlying coins in the pool
     * @param i The index value for the underlying coin to send
     * @param j The index value of the underlying coin to receive
     * @param _dx The amount of coin `i` being exchanged
     * @param _min_dy The minimum amount of coin `j` to receive
     * @return The actual amount of coin `j` received after the exchange
     */
    function exchange_underlying(int128 i, int128 j, uint256 _dx, uint256 _min_dy) external returns (uint256);

    /**
     * @notice Calculate the amount of one underlying coin that can be received for another
     * @dev Provides a quote of how much of coin `j` one would receive for a given amount of coin `i`
     * @param i The index value for the underlying coin to send
     * @param j The index value of the underlying coin to receive
     * @param _dx The amount of coin `i` being exchanged
     * @return The amount of coin `j` that can be received for the given amount of coin `i`
     */
    function get_dy_underlying(int128 i, int128 j, uint256 _dx) external view returns (uint256);
}