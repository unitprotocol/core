# Solidity API

## BridgedUsdpOracle

_Oracle to quote bridged from other chains USDP_

### Q112

```solidity
uint256 Q112
```

### bridgedUsdp

```solidity
mapping(address => bool) bridgedUsdp
```

### Added

```solidity
event Added(address _usdp)
```

### Removed

```solidity
event Removed(address _usdp)
```

### constructor

```solidity
constructor(address vaultParameters, address[] _bridgedUsdp) public
```

### add

```solidity
function add(address _usdp) external
```

### remove

```solidity
function remove(address _usdp) external
```

### assetToUsd

```solidity
function assetToUsd(address asset, uint256 amount) public view returns (uint256)
```

