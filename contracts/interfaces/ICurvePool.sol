// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title ICurvePool
 * @dev Interface for interacting with Curve.fi pools
 */
interface ICurvePool {
    
    /**
     * @dev Get the virtual price, which is the value of 1 LP token in the underlying stablecoins
     * @return uint The current virtual price
     */
    function get_virtual_price() external view returns (uint);
    
    /**
     * @dev Get the address of the specified coin in the pool
     * @param index The index of the coin to retrieve
     * @return address The address of the coin at the specified index
     */
    function coins(uint index) external view returns (address);
}