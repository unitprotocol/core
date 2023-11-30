// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity 0.7.6;

import "./EmptyToken.sol";
import "../interfaces/IWstEthToken.sol";
import "../interfaces/IStETH.sol";

/**
 * @title WstETH
 * @dev This contract wraps stETH tokens into wstETH tokens to provide liquidity.
 */
contract WstETH is EmptyToken, IWstEthToken {

  /**
   * @dev Address of the stETH token.
   */
  address public stETHAddr;

  /**
   * @notice Creates an instance of the wstETH token.
   * @param _totalSupply Initial total supply of wstETH.
   * @param _stEth Address of the stETH token to wrap.
   */
  constructor(
    uint256 _totalSupply,
    address _stEth
  ) EmptyToken(
    "Wrapped liquid staked Ether 2.0",
    "wstETH",
    18,
    _totalSupply,
    msg.sender
  ) {
    stETHAddr = _stEth;
  }

  /**
   * @notice Given an amount of wstETH, calculates the amount of stETH that the wstETH is worth.
   * @param _wstETHAmount Amount of wstETH to convert to stETH.
   * @return The equivalent amount of stETH.
   */
  function getStETHByWstETH(uint256 _wstETHAmount) public override view returns (uint256) {
    return IStETH(stETHAddr).getPooledEthByShares(_wstETHAmount);
  }

  /**
   * @notice Gets the current address of the stETH token.
   * @return The address of the stETH token.
   */
  function stETH() public override view returns (address) {
    return stETHAddr;
  }

}