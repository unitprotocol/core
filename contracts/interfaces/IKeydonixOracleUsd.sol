pragma abicoder v2;

interface IKeydonixOracleUsd {

    struct ProofDataStruct {
        bytes block;
        bytes accountProofNodesRlp;
        bytes reserveAndTimestampProofNodesRlp;
        bytes priceAccumulatorProofNodesRlp;
    }

    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount, ProofDataStruct calldata proofData) external view returns (uint);
}