# Solidity API

## KeydonixOracleAbstract

### Q112

```solidity
uint256 Q112
```

### ProofDataStruct

```solidity
struct ProofDataStruct {
  bytes block;
  bytes accountProofNodesRlp;
  bytes reserveAndTimestampProofNodesRlp;
  bytes priceAccumulatorProofNodesRlp;
}
```

### assetToUsd

```solidity
function assetToUsd(address asset, uint256 amount, struct KeydonixOracleAbstract.ProofDataStruct proofData) public view virtual returns (uint256)
```

