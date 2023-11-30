// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IStableSwapStateOracle Interface
 * @dev Interface for a contract that provides the price of stETH token.
 */
interface IStableSwapStateOracle {
  
  /**
   * @dev Returns the current price of stETH token
   * @return The price of stETH
   */
  function stethPrice() external view returns (uint256);
}