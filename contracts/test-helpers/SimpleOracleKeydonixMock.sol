// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../oracles/KeydonixOracleAbstract.sol";

/**
 * @title SimpleOracleKeydonixMock
 * @dev Used in tests
 **/
contract SimpleOracleKeydonixMock is KeydonixOracleAbstract {

    uint public rate = 500 * 2**112;

    function setRate(uint _rate) public {
        rate = _rate;
    }

    function assetToUsd(address /* asset */, uint amount, ProofDataStruct memory proofData) public override view returns (uint) {
        require(keccak256(proofData.block) == keccak256(hex"01"), "Unit Protocol: proofData.block");
        require(keccak256(proofData.accountProofNodesRlp) == keccak256(hex"02"), "Unit Protocol: proofData.accountProofNodesRlp");
        require(keccak256(proofData.reserveAndTimestampProofNodesRlp) == keccak256(hex"03"), "Unit Protocol: proofData.reserveAndTimestampProofNodesRlp");
        require(keccak256(proofData.priceAccumulatorProofNodesRlp) == keccak256(hex"04"), "Unit Protocol: proofData.priceAccumulatorProofNodesRlp");

        return amount * rate;
    }
}
