# Solidity API

## IUniswapV2Factory

### PairCreated

```solidity
event PairCreated(address token0, address token1, address pair, uint256)
```

### getPair

```solidity
function getPair(address tokenA, address tokenB) external view returns (address pair)
```

### allPairs

```solidity
function allPairs(uint256) external view returns (address pair)
```

### allPairsLength

```solidity
function allPairsLength() external view returns (uint256)
```

### feeTo

```solidity
function feeTo() external view returns (address)
```

### feeToSetter

```solidity
function feeToSetter() external view returns (address)
```

### createPair

```solidity
function createPair(address tokenA, address tokenB) external returns (address pair)
```

