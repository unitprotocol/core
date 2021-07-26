// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IStEthPriceFeed {
    function current_price() external view returns (uint256,bool);
    function full_price_info() external view returns (uint256,bool,uint256);
}
