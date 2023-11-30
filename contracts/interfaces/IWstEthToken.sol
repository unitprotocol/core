// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IWstEthToken
 * @dev Interface for the Wrapped stETH (wstETH) token contract.
 */
interface IWstEthToken {
    
    /**
     * @dev Returns the address of the underlying stETH token.
     * @return address The address of the stETH token.
     */
    function stETH() external view returns (address);
    
    /**
     * @dev Given an amount of wstETH, returns the equivalent amount of stETH.
     * @param _wstETHAmount The amount of wstETH to convert.
     * @return uint256 The equivalent amount of stETH.
     */
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
}