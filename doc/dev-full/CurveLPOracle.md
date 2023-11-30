# Solidity API

## CurveLPOracle

_Oracle to quote curve LP tokens_

### Q112

```solidity
uint256 Q112
```

### PRECISION

```solidity
uint256 PRECISION
```

### curveProvider

```solidity
contract ICurveProvider curveProvider
```

### oracleRegistry

```solidity
contract IOracleRegistry oracleRegistry
```

### constructor

```solidity
constructor(address _curveProvider, address _oracleRegistry) public
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _curveProvider | address | The address of the Curve Provider. Mainnet: 0x0000000022D53366457F9d5E68Ec105046FC4383 |
| _oracleRegistry | address | The address of the OracleRegistry contract |

### assetToUsd

```solidity
function assetToUsd(address asset, uint256 amount) public view returns (uint256)
```

