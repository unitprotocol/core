// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface ICurveTricrypto2Pool {
    function get_virtual_price() external view returns (uint);
    function coins(uint) external view returns (address);
    function N_COINS() external view returns (uint);

    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool use_eth) external;
    function get_dy(uint256, uint256, uint256) external view returns (uint256);
}