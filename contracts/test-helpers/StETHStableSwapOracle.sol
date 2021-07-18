// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity 0.7.6;

import "../interfaces/IStableSwapStateOracle.sol";

contract StETHStableSwapOracle is IStableSwapStateOracle {

  uint256 public price;

  constructor(uint256 _price) {
    price = _price;
  }

  function stethPrice() public override view returns (uint256) {
    return price;
  }

}
