// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity 0.7.6;

import "./EmptyToken.sol";
import "../interfaces/IWstEthToken.sol";
import "../interfaces/IStETH.sol";

contract WstETH is EmptyToken, IWstEthToken {

  address public stETHAddr;

  constructor(
    uint256          _totalSupply,
    address          _stEth
  ) EmptyToken(
    "Wrapped liquid staked Ether 2.0",
    "wstETH",
    18,
    _totalSupply,
    msg.sender
  ) {
    stETHAddr = _stEth;
  }

  function getStETHByWstETH(uint256 _wstETHAmount) public override view returns (uint256) {
    return IStETH(stETHAddr).getPooledEthByShares(_wstETHAmount);
  }

  function stETH() public override view returns (address) {
    return stETHAddr;
  }

}
