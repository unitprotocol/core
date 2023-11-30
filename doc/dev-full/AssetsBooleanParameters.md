# Solidity API

## AssetsBooleanParameters

### values

```solidity
mapping(address => uint256) values
```

### constructor

```solidity
constructor(address _vaultParameters, address[] _initialAssets, uint8[] _initialParams) public
```

### get

```solidity
function get(address _asset, uint8 _param) external view returns (bool)
```

Get value of _param for _asset

_see ParametersConstants_

### getAll

```solidity
function getAll(address _asset) external view returns (uint256)
```

Get values of all params for _asset. The 0th bit of returned uint id the value of param=0, etc

### set

```solidity
function set(address _asset, uint8 _param, bool _value) public
```

Set value of _param for _asset

_see ParametersConstants_

### _set

```solidity
function _set(address _asset, uint8 _param, bool _value) internal
```

