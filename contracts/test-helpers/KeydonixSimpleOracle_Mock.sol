// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../oracles/KeydonixOracleAbstract.sol";

/* @title KeydonixSimpleOracle_Mock
 * @dev Mock implementation of the KeydonixOracleAbstract used for testing purposes.
 */
contract KeydonixSimpleOracle_Mock is KeydonixOracleAbstract {

    /// @notice The current rate used to convert assets to USD.
    uint public rate;

    /* @notice Sets the rate used in the conversion from asset to USD.
     * @param _rate The new rate to be set.
     */
    function setRate(uint _rate) public {
        rate = _rate;
    }

    /* @notice Converts the amount of the asset to its equivalent in USD.
     * @param amount The amount of the asset to convert.
     * @param proofData The proof data required for the conversion, used here for validation.
     * @return The equivalent amount in USD.
     * @dev This mock implementation requires specific proofData to simulate the oracle check.
     * @dev Throws if the proofData does not match the expected mock values.
     */
    function assetToUsd(address /* asset */, uint amount, ProofDataStruct memory proofData) public override view returns (uint) {
        require(keccak256(proofData.block) == keccak256(hex"01"), "Unit Protocol: proofData.block");
        require(keccak256(proofData.accountProofNodesRlp) == keccak256(hex"02"), "Unit Protocol: proofData.accountProofNodesRlp");
        require(keccak256(proofData.reserveAndTimestampProofNodesRlp) == keccak256(hex"03"), "Unit Protocol: proofData.reserveAndTimestampProofNodesRlp");
        require(keccak256(proofData.priceAccumulatorProofNodesRlp) == keccak256(hex"04"), "Unit Protocol: proofData.priceAccumulatorProofNodesRlp");

        return amount * rate;
    }
}