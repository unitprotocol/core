// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

import "./ICurvePoolBase.sol";

interface ICurvePoolMeta is ICurvePoolBase {

    function base_pool() external view returns (address);

    /**
     * @dev variant of token/3crv pool
     * @param i Index value for the underlying coin to send
     * @param j Index value of the underlying coin to recieve
     * @param _dx Amount of `i` being exchanged
     * @param _min_dy Minimum amount of `j` to receive
     * @return Actual amount of `j` received
     */
    function exchange_underlying(int128 i, int128 j, uint256 _dx, uint256 _min_dy) external returns (uint256);

    function get_dy_underlying(int128 i, int128 j, uint256 _dx) external view returns (uint256);
}