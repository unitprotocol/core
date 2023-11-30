// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity 0.7.6;

import "../interfaces/IStableSwap.sol";

/**
 * @title StETHCurvePool
 * @dev Implementation of a mock Curve pool for stETH/ETH trading pair.
 */
contract StETHCurvePool is IStableSwap {

  /// @notice The price of stETH in terms of ETH.
  uint256 public price;

  /// @dev Index of stETH in the Curve pool.
  uint256 public constant CURVE_STETH_INDEX = 0;
  /// @dev Index of ETH in the Curve pool.
  uint256 public constant CURVE_ETH_INDEX = 1;

  /**
   * @dev Sets the initial price of stETH.
   * @param _price Initial price of stETH in terms of ETH.
   */
  constructor(uint256 _price) {
    price = _price;
  }

  /**
   * @notice Calculates the number of destination tokens you receive for the amount of source tokens you provide.
   * @dev Mock implementation always returns the current price for a fixed input.
   * @param x The index of the source token in the pool.
   * @param y The index of the destination token in the pool.
   * @param dx The amount of source tokens you want to convert.
   * @return The amount of destination tokens you will receive.
   * @throws if the input variables do not meet the required conditions.
   */
  function get_dy(uint256 x, uint256 y, uint256 dx) public override view returns (uint256) {
    require(x == CURVE_STETH_INDEX && y == CURVE_ETH_INDEX && dx == 10**18,'CHECK_INCOME_VARIABLES_FAILED');
    return price;
  }

}