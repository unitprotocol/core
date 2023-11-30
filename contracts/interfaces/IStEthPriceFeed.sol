// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title Interface for StEth Price Feed
 * @dev Interface to interact with the StEth price feed oracle.
 */
interface IStEthPriceFeed {
    
    /**
     * @notice Get the current price of StEth.
     * @dev Returns the latest price of StEth.
     * @return uint256 The current price.
     * @return bool True if the current price is valid, false if invalid.
     */
    function current_price() external view returns (uint256,bool);
    
    /**
     * @notice Get detailed price information of StEth.
     * @dev Returns the full price information including the price, validity, and timestamp.
     * @return uint256 The current price.
     * @return bool True if the current price is valid, false if invalid.
     * @return uint256 The timestamp of the last price update.
     */
    function full_price_info() external view returns (uint256,bool,uint256);
}