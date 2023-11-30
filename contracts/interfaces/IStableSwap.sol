// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IStableSwap Interface
 * @dev Interface for the StableSwap contract.
 */
interface IStableSwap {

    /**
     * @notice Calculate the amount of token y you receive for token x with an amount of dx
     * @param x The index of the token being sold
     * @param y The index of the token being bought
     * @param dx The amount of token x being sold
     * @return The amount of token y that will be received
     */
    function get_dy(uint256 x, uint256 y, uint256 dx) external view returns (uint256);
}