// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title Interface for WETH
 * @dev Wrapped Ether Interface to interact with WETH tokens in contracts
 */
interface IWETH {
    /**
     * @dev Deposit ether to get wrapped ether
     * @notice Call this function along with some ether to get wrapped ether
     */
    function deposit() external payable;
    
    /**
     * @dev Transfer wrapped ether to a specified address
     * @param to The address to transfer to
     * @param value The amount of wrapped ether to be transferred
     * @return success A boolean that indicates if the operation was successful
     */
    function transfer(address to, uint value) external returns (bool success);
    
    /**
     * @dev Transfer wrapped ether from one address to another
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of wrapped ether to be transferred
     * @return success A boolean that indicates if the operation was successful
     */
    function transferFrom(address from, address to, uint value) external returns (bool success);
    
    /**
     * @dev Withdraw ether from the contract by unwrapping the wrapped ether
     * @param amount The amount of wrapped ether to unwrap
     */
    function withdraw(uint amount) external;
}