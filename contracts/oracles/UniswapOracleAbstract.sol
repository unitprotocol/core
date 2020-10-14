// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;


/**
 * @title UniswapOracleAbstract
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
abstract contract UniswapOracleAbstract {

    uint public constant Q112 = 2 ** 112;

    struct ProofDataStruct {
        bytes block;
        bytes accountProofNodesRlp;
        bytes reserveAndTimestampProofNodesRlp;
        bytes priceAccumulatorProofNodesRlp;
    }

    function assetToUsd(
        address asset,
        uint amount,
        ProofDataStruct memory proofData
    ) public virtual view returns (uint) {}
}
