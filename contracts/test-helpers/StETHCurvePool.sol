// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity 0.7.6;

import "../interfaces/IStableSwap.sol";

contract StETHCurvePool is IStableSwap {

  uint256 public price;

  uint256 public constant CURVE_STETH_INDEX = 0;
  uint256 public constant CURVE_ETH_INDEX = 1;

  constructor(uint256 _price) {
    price = _price;
  }

  function get_dy(uint256 x, uint256 y, uint256 dx) public override view returns (uint256) {
    require(x == CURVE_STETH_INDEX && y == CURVE_ETH_INDEX && dx == 10**18,'CHECK_INCOME_VARIABLES_FAILED');
    return price;
  }

}
