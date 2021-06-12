// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./EmptyToken.sol";


contract YvWETH is EmptyToken {

  address public token;

  uint256 public pricePerShare;

  bool public emergencyShutdown;

    constructor(
        uint256          _totalSupply,
        address          _token,
        uint256          _pricePerShare,
        bool             _emergencyShutdown
    ) EmptyToken(
        "WETH yVault",
        "yvWETH",
        18,
        _totalSupply,
        msg.sender
    )
    public {
      token = _token;
      pricePerShare = _pricePerShare;
      emergencyShutdown = _emergencyShutdown;
    }

}
