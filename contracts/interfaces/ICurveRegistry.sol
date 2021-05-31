// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface ICurveRegistry {
    function get_pool_from_lp_token(address) external view returns (address);
    function get_n_coins(address) external view returns (uint[2] memory);
}