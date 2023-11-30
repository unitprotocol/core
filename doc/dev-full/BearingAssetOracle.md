# Solidity API

## BearingAssetOracle

_Wrapper to quote bearing assets like xSUSHI_

### oracleRegistry

```solidity
contract IOracleRegistry oracleRegistry
```

### underlyings

```solidity
mapping(address => address) underlyings
```

### NewUnderlying

```solidity
event NewUnderlying(address bearing, address underlying)
```

### constructor

```solidity
constructor(address _vaultParameters, address _oracleRegistry) public
```

### setUnderlying

```solidity
function setUnderlying(address bearing, address underlying) external
```

### assetToUsd

```solidity
function assetToUsd(address bearing, uint256 amount) public view returns (uint256)
```

### bearingToUnderlying

```solidity
function bearingToUnderlying(address bearing, uint256 amount) public view returns (address, uint256)
```

