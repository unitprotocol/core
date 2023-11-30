// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title Interface for Yearn Vault Token (yvToken)
 */
interface IyvToken {
    
    /**
     * @notice Retrieves the underlying token address.
     * @return address The address of the underlying token.
     */
    function token() external view returns (address);
    
    /**
     * @notice Retrieves the number of decimals for the vault token.
     * @return uint256 The number of decimals used by the vault token.
     */
    function decimals() external view returns (uint256);
    
    /**
     * @notice Retrieves the current price per share of the vault token.
     * @return uint256 The current price per share.
     */
    function pricePerShare() external view returns (uint256);
    
    /**
     * @notice Checks if the vault is in emergency shutdown mode.
     * @return bool True if the vault is in emergency shutdown, false otherwise.
     */
    function emergencyShutdown() external view returns (bool);
}