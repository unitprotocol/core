# Solidity API

## OraclePoolToken

_Calculates the USD price of Uniswap LP tokens_

### oracleRegistry

```solidity
contract IOracleRegistry oracleRegistry
```

### WETH

```solidity
address WETH
```

### Q112

```solidity
uint256 Q112
```

### constructor

```solidity
constructor(address _oracleRegistry) public
```

### assetToUsd

```solidity
function assetToUsd(address asset, uint256 amount) public view returns (uint256)
```

Flashloan-resistant logic to determine USD price of Uniswap LP tokens
Pair must be registered at Chainlink

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The LP token address |
| amount | uint256 | Amount of asset |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Q112 encoded price of asset in USD |

### sqrt

```solidity
function sqrt(uint256 x) internal pure returns (uint256 y)
```

