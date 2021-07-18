// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IWstEthToken {
    function stETH() external view returns (address);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
}
