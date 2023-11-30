// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title Interface for the StETH contract
 */
interface IStETH {
  
  /**
   * @notice Calculate the amount of Ether pooled for the given amount of shares
   * @param _sharesAmount The amount of shares
   * @return The amount of pooled Ether
   */
  function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
}