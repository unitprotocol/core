# Solidity API

## CDPRegistry

### CDP

```solidity
struct CDP {
  address asset;
  address owner;
}
```

### cdpList

```solidity
mapping(address => address[]) cdpList
```

### cdpIndex

```solidity
mapping(address => mapping(address => uint256)) cdpIndex
```

### vault

```solidity
contract IVault vault
```

### cr

```solidity
contract ICollateralRegistry cr
```

### Added

```solidity
event Added(address asset, address owner)
```

### Removed

```solidity
event Removed(address asset, address owner)
```

### constructor

```solidity
constructor(address _vault, address _collateralRegistry) public
```

### checkpoint

```solidity
function checkpoint(address asset, address owner) public
```

### batchCheckpointForAsset

```solidity
function batchCheckpointForAsset(address asset, address[] owners) external
```

### batchCheckpoint

```solidity
function batchCheckpoint(address[] assets, address[] owners) external
```

### isAlive

```solidity
function isAlive(address asset, address owner) public view returns (bool)
```

### isListed

```solidity
function isListed(address asset, address owner) public view returns (bool)
```

### _removeCdp

```solidity
function _removeCdp(address asset, address owner) internal
```

### _addCdp

```solidity
function _addCdp(address asset, address owner) internal
```

### getCdpsByCollateral

```solidity
function getCdpsByCollateral(address asset) external view returns (struct CDPRegistry.CDP[] cdps)
```

### getCdpsByOwner

```solidity
function getCdpsByOwner(address owner) external view returns (struct CDPRegistry.CDP[] r)
```

### getAllCdps

```solidity
function getAllCdps() external view returns (struct CDPRegistry.CDP[] r)
```

### getCdpsCount

```solidity
function getCdpsCount() public view returns (uint256 totalCdpCount)
```

### getCdpsCountForCollateral

```solidity
function getCdpsCountForCollateral(address asset) public view returns (uint256)
```

