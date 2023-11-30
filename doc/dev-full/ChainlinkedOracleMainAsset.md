# Solidity API

## ChainlinkedOracleMainAsset

_Calculates the USD price of desired tokens_

### usdAggregators

```solidity
mapping(address => address) usdAggregators
```

### ethAggregators

```solidity
mapping(address => address) ethAggregators
```

### Q112

```solidity
uint256 Q112
```

### USD_TYPE

```solidity
uint256 USD_TYPE
```

### ETH_TYPE

```solidity
uint256 ETH_TYPE
```

### WETH

```solidity
address WETH
```

### NewAggregator

```solidity
event NewAggregator(address asset, address aggregator, uint256 aggType)
```

### constructor

```solidity
constructor(address[] tokenAddresses1, address[] _usdAggregators, address[] tokenAddresses2, address[] _ethAggregators, address weth, address vaultParameters) public
```

### setAggregators

```solidity
function setAggregators(address[] tokenAddresses1, address[] _usdAggregators, address[] tokenAddresses2, address[] _ethAggregators) external
```

### assetToUsd

```solidity
function assetToUsd(address asset, uint256 amount) public view returns (uint256)
```

{asset}/USD or {asset}/ETH pair must be registered at Chainlink

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The token address |
| amount | uint256 | Amount of tokens |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Q112-encoded price of asset amount in USD |

### _assetToUsd

```solidity
function _assetToUsd(address asset, uint256 amount) internal view returns (uint256)
```

### assetToEth

```solidity
function assetToEth(address asset, uint256 amount) public view returns (uint256)
```

{asset}/ETH pair must be registered at Chainlink

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The token address |
| amount | uint256 | Amount of tokens |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Q112-encoded price of asset amount in ETH |

### ethToUsd

```solidity
function ethToUsd(uint256 ethAmount) public view returns (uint256)
```

ETH/USD price feed from Chainlink, see for more info: https://feeds.chain.link/eth-usd
returns The price of given amount of Ether in USD (0 decimals)

### usdToEth

```solidity
function usdToEth(uint256 _usdAmount) public view returns (uint256)
```

