// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity ^0.7.6;

import "../interfaces/IStableSwap.sol";
import "../interfaces/IStableSwapStateOracle.sol";

/**
 * @title StETHPriceFeed
 * @dev Contract to interact with the Curve pool for stETH and provide price feeds.
 */
contract StETHPriceFeed {

  /* @notice The address of the Curve pool contract. */
  address public curve_pool_address;

  /* @notice The address of the stable swap state oracle contract. */
  address public stable_swap_oracle_address;

  /* @notice Index of stETH in the Curve pool. */
  uint256 public constant CURVE_STETH_INDEX = 0;

  /* @notice Index of ETH in the Curve pool. */
  uint256 public constant CURVE_ETH_INDEX = 1;

  /* @notice Maximum accepted price difference in basis points. */
  uint256 public constant max_safe_price_difference = 1000;

  /**
   * @dev Constructor for StETHPriceFeed.
   * @param _curve_pool_address The address of the Curve pool.
   * @param _stable_swap_oracle_address The address of the stable swap state oracle.
   */
  constructor(
    address _curve_pool_address,
    address _stable_swap_oracle_address
  ) {
    curve_pool_address = _curve_pool_address;
    stable_swap_oracle_address = _stable_swap_oracle_address;
  }

  /**
   * @dev Internal function to calculate the percentage difference between two values.
   * @param newVal The new value for comparison.
   * @param oldVal The old value for comparison.
   * @return The percentage difference.
   */
  function _percentage_diff(uint256 newVal, uint256 oldVal) internal pure returns (uint256) {
    if (newVal > oldVal) {
      return (newVal - oldVal) * 10000 / oldVal;
    } else {
      return (oldVal - newVal) * 10000 / oldVal;
    }
  }

  /**
   * @dev Internal function to fetch the current price from the Curve pool and compare it with the oracle price.
   * @return pool_price The price from the Curve pool.
   * @return has_changed_unsafely Boolean indicating if the price has changed unsafely.
   * @return oracle_price The price from the oracle.
   */
  function _current_price() internal view returns (uint256 pool_price, bool has_changed_unsafely, uint256 oracle_price) {
    pool_price = IStableSwap(curve_pool_address).get_dy(CURVE_STETH_INDEX, CURVE_ETH_INDEX, 10**18);
    oracle_price = IStableSwapStateOracle(stable_swap_oracle_address).stethPrice();
    has_changed_unsafely = _percentage_diff(pool_price, oracle_price) > max_safe_price_difference;
  }

  /**
   * @notice Fetches the current price and indicates if it's considered safe.
   * @return The current price from the Curve pool.
   * @return Boolean indicating if the price is considered safe.
   */
  function current_price() public view returns (uint256, bool) {
    uint256 currentPrice = 0;
    bool has_changed_unsafely = true;
    uint256 oracle_price = 0;
    (currentPrice, has_changed_unsafely, oracle_price) = _current_price();
    bool is_safe = currentPrice <= 10**18 && !has_changed_unsafely;
    return (currentPrice, is_safe);
  }

  /**
   * @notice Fetches the full price information including the oracle price and safety status.
   * @return The current price from the Curve pool.
   * @return Boolean indicating if the price is considered safe.
   * @return The current price from the oracle.
   */
  function full_price_info() public view returns (uint256, bool, uint256) {
    uint256 currentPrice = 0;
    bool has_changed_unsafely = true;
    uint256 oracle_price = 0;
    (currentPrice, has_changed_unsafely, oracle_price) = _current_price();
    bool is_safe = currentPrice <= 10**18 && !has_changed_unsafely;
    return (currentPrice, is_safe, oracle_price);
  }

}