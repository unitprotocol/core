// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

import "../ICurvePool.sol";

interface ICurvePoolCrypto is ICurvePool {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;
    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);
}