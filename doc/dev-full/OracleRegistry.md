# Solidity API

## OracleRegistry

### Oracle

```solidity
struct Oracle {
  uint256 oracleType;
  address oracleAddress;
}
```

### maxOracleType

```solidity
uint256 maxOracleType
```

### WETH

```solidity
address WETH
```

### oracleTypeByAsset

```solidity
mapping(address => uint256) oracleTypeByAsset
```

### oracleByType

```solidity
mapping(uint256 => address) oracleByType
```

### oracleTypeByOracle

```solidity
mapping(address => uint256) oracleTypeByOracle
```

### keydonixOracleTypes

```solidity
uint256[] keydonixOracleTypes
```

### AssetOracle

```solidity
event AssetOracle(address asset, uint256 oracleType)
```

### OracleType

```solidity
event OracleType(uint256 oracleType, address oracle)
```

### KeydonixOracleTypes

```solidity
event KeydonixOracleTypes()
```

### validAddress

```solidity
modifier validAddress(address asset)
```

### validType

```solidity
modifier validType(uint256 _type)
```

### constructor

```solidity
constructor(address vaultParameters, address _weth) public
```

### setKeydonixOracleTypes

```solidity
function setKeydonixOracleTypes(uint256[] _keydonixOracleTypes) public
```

### setOracle

```solidity
function setOracle(uint256 oracleType, address oracle) public
```

### unsetOracle

```solidity
function unsetOracle(uint256 oracleType) public
```

### setOracleTypeForAsset

```solidity
function setOracleTypeForAsset(address asset, uint256 oracleType) public
```

### setOracleTypeForAssets

```solidity
function setOracleTypeForAssets(address[] assets, uint256 oracleType) public
```

### unsetOracleForAsset

```solidity
function unsetOracleForAsset(address asset) public
```

### unsetOracleForAssets

```solidity
function unsetOracleForAssets(address[] assets) public
```

### getOracles

```solidity
function getOracles() external view returns (struct OracleRegistry.Oracle[] foundOracles)
```

### getKeydonixOracleTypes

```solidity
function getKeydonixOracleTypes() external view returns (uint256[])
```

### oracleByAsset

```solidity
function oracleByAsset(address asset) external view returns (address)
```

