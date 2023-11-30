// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./EmptyToken.sol";

/* 
 * @title YvWETH
 * @notice YvWETH is a contract for a token that represents a share of a pool of WETH in the Yearn Finance protocol.
 * @dev Inheritance from EmptyToken contract with added functionality specific to a yVault for WETH.
 */
contract YvWETH is EmptyToken {

  /* @notice Address of the underlying token which is WETH. */
  address public token;

  /* @notice The price per share of the yVault, denominated in the underlying token. */
  uint256 public pricePerShare;

  /* 
   * @dev Constructor for YvWETH which sets up the yVault token.
   * @param _totalSupply The initial total supply of yVault tokens.
   * @param _token The address of the underlying token, which should be WETH.
   * @param _pricePerShare The initial price per share for the yVault.
   */
  constructor(
      uint256 _totalSupply,
      address _token,
      uint256 _pricePerShare
  ) EmptyToken(
      "WETH yVault",
      "yvWETH",
      18,
      _totalSupply,
      msg.sender
  ) {
    token = _token;
    pricePerShare = _pricePerShare;
  }

}