// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity 0.7.6;

import "../interfaces/IStableSwapStateOracle.sol";

/* 
 * @title StETHStableSwapOracle
 * @notice Oracle contract for stETH price that implements IStableSwapStateOracle interface.
 * @dev This contract provides the functionality to report and retrieve the price of stETH.
 */
contract StETHStableSwapOracle is IStableSwapStateOracle {

  /* @notice The reported price of stETH */
  uint256 public price;

  /* 
   * @dev Constructor for StETHStableSwapOracle sets the initial price of stETH.
   * @param _price The initial price of stETH to be set.
   */
  constructor(uint256 _price) {
    price = _price;
  }

  /* 
   * @notice Gets the current price of stETH.
   * @dev Returns the latest price of stETH reported by the oracle.
   * @return The current price of stETH.
   */
  function stethPrice() public override view returns (uint256) {
    return price;
  }

}