// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

import "../ICurvePool.sol";

/**
 * @title ICurvePoolBase
 * @dev Extension of ICurvePool interface that includes exchange functionality
 */
interface ICurvePoolBase is ICurvePool {

    /**
     * @notice Perform an exchange between two coins
     * @dev Index values can be found via the `coins` public getter method.
     * @param i The index value for the coin to send
     * @param j The index value for the coin to receive
     * @param _dx The amount of `i` being exchanged
     * @param _min_dy The minimum amount of `j` to receive
     * @return The actual amount of `j` received
     */
    function exchange(int128 i, int128 j, uint256 _dx, uint256 _min_dy) external returns (uint256);

    /**
     * @notice Calculate the amount of `j` received when exchanging `i`
     * @param i The index value for the coin to send
     * @param j The index value for the coin to receive
     * @param _dx The amount of `i` being exchanged
     * @return The calculated amount of `j` that will be received
     */
    function get_dy(int128 i, int128 j, uint256 _dx) external view returns (uint256);
}