# Solidity API

## SwappersRegistry

### SwapperInfo

```solidity
struct SwapperInfo {
  uint240 id;
  bool exists;
}
```

### swappersInfo

```solidity
mapping(contract ISwapper => struct SwappersRegistry.SwapperInfo) swappersInfo
```

### swappers

```solidity
contract ISwapper[] swappers
```

### constructor

```solidity
constructor(address _vaultParameters) public
```

### getSwappersLength

```solidity
function getSwappersLength() external view returns (uint256)
```

### getSwapperId

```solidity
function getSwapperId(contract ISwapper _swapper) external view returns (uint256)
```

### getSwapper

```solidity
function getSwapper(uint256 _id) external view returns (contract ISwapper)
```

### hasSwapper

```solidity
function hasSwapper(contract ISwapper _swapper) public view returns (bool)
```

### getSwappers

```solidity
function getSwappers() external view returns (contract ISwapper[])
```

### add

```solidity
function add(contract ISwapper _swapper) public
```

### remove

```solidity
function remove(contract ISwapper _swapper) public
```

