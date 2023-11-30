// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title IUniswapV2Factory
 * @dev Interface for the Uniswap V2 Factory.
 */
interface IUniswapV2Factory {
    /**
     * @dev Emitted when a new pair is created.
     * @param token0 The address of the first token.
     * @param token1 The address of the second token.
     * @param pair The address of the created pair.
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    /**
     * @dev Returns the address of the pair for tokenA and tokenB, if it exists.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return pair The address of the pair.
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    /**
     * @dev Returns the address of the n-th pair.
     * @param index The index of the pair in the list of all pairs.
     * @return pair The address of the pair.
     */
    function allPairs(uint index) external view returns (address pair);

    /**
     * @dev Returns the total number of pairs.
     * @return The total number of pairs.
     */
    function allPairsLength() external view returns (uint);

    /**
     * @dev Returns the fee to address.
     * @return The address to which fees are sent.
     */
    function feeTo() external view returns (address);

    /**
     * @dev Returns the address allowed to set feeTo.
     * @return The address allowed to set feeTo.
     */
    function feeToSetter() external view returns (address);

    /**
     * @dev Creates a pair for two tokens and returns the pair's address.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return pair The address of the created pair.
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);
}