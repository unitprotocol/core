// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity ^0.7.6;

import "../interfaces/IStableSwap.sol";
import "../interfaces/IStableSwapStateOracle.sol";

contract StETHPriceFeed {

  address public curve_pool_address;
  address public stable_swap_oracle_address;
  uint256 public constant CURVE_STETH_INDEX = 0;
  uint256 public constant CURVE_ETH_INDEX = 1;

  // Maximal difference accepted is 10% (1000)
  uint256 public constant max_safe_price_difference = 1000;

  constructor(
    address _curve_pool_address,
    address _stable_swap_oracle_address
  ) {
    curve_pool_address = _curve_pool_address;
    stable_swap_oracle_address = _stable_swap_oracle_address;
  }

  function _percentage_diff(uint256 newVal, uint256 oldVal) internal pure returns (uint256) {
    if (newVal > oldVal) {
      return (newVal - oldVal) * 10000 / oldVal;
    } else {
      return (oldVal - newVal) * 10000 / oldVal;
    }
  }

  function _current_price() internal view returns (uint256 pool_price, bool has_changed_unsafely, uint256 oracle_price) {
    pool_price = IStableSwap(curve_pool_address).get_dy(CURVE_STETH_INDEX, CURVE_ETH_INDEX, 10**18);
    oracle_price = IStableSwapStateOracle(stable_swap_oracle_address).stethPrice();
    has_changed_unsafely = _percentage_diff(pool_price, oracle_price) > max_safe_price_difference;
  }

  function current_price() public view returns (uint256, bool) {
    uint256 currentPrice = 0;
    bool has_changed_unsafely = true;
    uint256 oracle_price = 0;
    (currentPrice, has_changed_unsafely, oracle_price) = _current_price();
    bool is_safe = currentPrice <= 10**18 && !has_changed_unsafely;
    return (currentPrice, is_safe);
  }

  function full_price_info() public view returns (uint256, bool, uint256) {
    uint256 currentPrice = 0;
    bool has_changed_unsafely = true;
    uint256 oracle_price = 0;
    (currentPrice, has_changed_unsafely, oracle_price) = _current_price();
    bool is_safe = currentPrice <= 10**18 && !has_changed_unsafely;
    return (currentPrice, is_safe, oracle_price);
  }

}
