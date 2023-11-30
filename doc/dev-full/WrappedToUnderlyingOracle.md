# Solidity API

## WrappedToUnderlyingOracle

_Oracle to quote wrapped tokens to underlying_

### oracleRegistry

```solidity
contract IOracleRegistry oracleRegistry
```

### assetToUnderlying

```solidity
mapping(address => address) assetToUnderlying
```

### NewUnderlying

```solidity
event NewUnderlying(address wrapped, address underlying)
```

### constructor

```solidity
constructor(address _vaultParameters, address _oracleRegistry) public
```

### setUnderlying

```solidity
function setUnderlying(address wrapped, address underlying) external
```

### assetToUsd

```solidity
function assetToUsd(address asset, uint256 amount) public view returns (uint256)
```

### _getOracleAndUnderlying

```solidity
function _getOracleAndUnderlying(address asset) internal view returns (address oracle, address underlying)
```

