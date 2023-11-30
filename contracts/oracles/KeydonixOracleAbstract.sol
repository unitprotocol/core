// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

/**
 * @title KeydonixOracleAbstract
 * @dev Abstract contract for Keydonix Oracle providing an interface to convert asset to USD value.
 */
abstract contract KeydonixOracleAbstract {

    /// @notice Constant used for decimal handling in calculations.
    uint public constant Q112 = 2 ** 112;

    /**
     * @dev Data structure representing the proof data required for price calculation.
     */
    struct ProofDataStruct {
        bytes block; // RLP encoded block header data.
        bytes accountProofNodesRlp; // RLP encoded account proof nodes.
        bytes reserveAndTimestampProofNodesRlp; // RLP encoded reserve and timestamp proof nodes.
        bytes priceAccumulatorProofNodesRlp; // RLP encoded price accumulator proof nodes.
    }

    /**
     * @notice Converts the amount of the asset into USD value based on the provided proof data.
     * @param asset The address of the asset to be converted.
     * @param amount The amount of the asset to be converted.
     * @param proofData The proof data required for conversion.
     * @return The USD value of the given amount of the asset.
     */
    function assetToUsd(
        address asset,
        uint amount,
        ProofDataStruct memory proofData
    ) public virtual view returns (uint);
}