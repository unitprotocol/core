// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/* 
 * @title OracleSimple
 * @dev Abstract contract for defining the interface of an oracle that converts asset amounts to USD.
 */
abstract contract OracleSimple {
    /**
     * @notice Convert an asset amount to USD
     * @param asset The address of the asset to convert
     * @param amount The amount of the asset to convert
     * @return The equivalent amount in USD
     */
    function assetToUsd(address asset, uint amount) public virtual view returns (uint);
}


/* 
 * @title OracleSimplePoolToken
 * @dev Abstract contract for an oracle that uses a main asset oracle for pool tokens.
 */
abstract contract OracleSimplePoolToken is OracleSimple {
    // Reference to the main asset oracle
    ChainlinkedOracleSimple public oracleMainAsset;
}


/* 
 * @title ChainlinkedOracleSimple
 * @dev Abstract contract for an oracle using Chainlink to convert assets to USD or ETH.
 */
abstract contract ChainlinkedOracleSimple is OracleSimple {
    // Address of the WETH token
    address public WETH;

    /**
     * @notice Convert an ETH amount to USD
     * @param ethAmount The amount of ETH to convert
     * @return The equivalent amount in USD
     */
    function ethToUsd(uint ethAmount) public virtual view returns (uint);

    /**
     * @notice Convert an asset amount to ETH
     * @param asset The address of the asset to convert
     * @param amount The amount of the asset to convert
     * @return The equivalent amount in ETH
     */
    function assetToEth(address asset, uint amount) public virtual view returns (uint);
}