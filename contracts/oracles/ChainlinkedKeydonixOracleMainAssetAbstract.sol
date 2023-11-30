// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./KeydonixOracleAbstract.sol";
pragma experimental ABIEncoderV2;

/**
 * @title ChainlinkedKeydonixOracleMainAssetAbstract
 * @dev Abstract contract for Chainlinked Keydonix Oracle for main assets.
 */
abstract contract ChainlinkedKeydonixOracleMainAssetAbstract is KeydonixOracleAbstract {

    /// @notice Address of Wrapped Ether (WETH)
    address public WETH;

    /**
     * @notice Converts the amount of the asset to ETH using proof data.
     * @param asset The address of the asset to be converted.
     * @param amount The amount of the asset to be converted.
     * @param proofData The proof data required for the conversion.
     * @return The equivalent amount of ETH.
     */
    function assetToEth(
        address asset,
        uint amount,
        ProofDataStruct memory proofData
    ) public virtual view returns (uint);

    /**
     * @notice Converts the amount of ETH to USD.
     * @param ethAmount The amount of ETH to be converted.
     * @return The equivalent amount of USD.
     */
    function ethToUsd(uint ethAmount) public virtual view returns (uint);
}