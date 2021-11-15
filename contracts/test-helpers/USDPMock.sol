// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../USDP.sol";


contract USDPMock is USDP {
  using SafeMath for uint;

  constructor(address _parameters) USDP(_parameters) {}

  function mintForTests(address to, uint amount) public {
    require(to != address(0), "Unit Protocol: ZERO_ADDRESS");

    balanceOf[to] = balanceOf[to].add(amount);
    totalSupply = totalSupply.add(amount);
  }
}
