# Solidity API

## WstEthOracle

_Wrapper to quote wstETH ERC20 token that represents the account's share of the total supply of stETH tokens. https://docs.lido.fi/contracts/wsteth/_

### oracleRegistry

```solidity
contract IOracleRegistry oracleRegistry
```

### stEthPriceFeed

```solidity
address stEthPriceFeed
```

### stEthDecimals

```solidity
uint256 stEthDecimals
```

### wstETH

```solidity
address wstETH
```

### addressWETH

```solidity
address addressWETH
```

### MAX_SAFE_PRICE_DIFF

```solidity
uint256 MAX_SAFE_PRICE_DIFF
```

### StEthPriceFeedChanged

```solidity
event StEthPriceFeedChanged(address implementation)
```

### constructor

```solidity
constructor(address _vaultParameters, address _oracleRegistry, address _wstETH, address _stETHPriceFeed) public
```

### setStEthPriceFeed

```solidity
function setStEthPriceFeed(address impl) external
```

### getDecimalsStEth

```solidity
function getDecimalsStEth() public view returns (uint256)
```

### assetToUsd

```solidity
function assetToUsd(address bearing, uint256 amount) public view returns (uint256)
```

