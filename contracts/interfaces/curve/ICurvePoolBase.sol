// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

import "../ICurvePool.sol";

interface ICurvePoolBase is ICurvePool {
    /**
     * @notice Perform an exchange between two coins
     * @dev Index values can be found via the `coins` public getter method
     * @param i Index value for the coin to send
     * @param j Index valie of the coin to recieve
     * @param _dx Amount of `i` being exchanged
     * @param _min_dy Minimum amount of `j` to receive
     * @return Actual amount of `j` received
     */
    function exchange(int128 i, int128 j, uint256 _dx, uint256 _min_dy) external returns (uint256);

    function get_dy(int128 i, int128 j, uint256 _dx) external view returns (uint256);
}