# Solidity API

## CollateralRegistry

### CollateralAdded

```solidity
event CollateralAdded(address asset)
```

### CollateralRemoved

```solidity
event CollateralRemoved(address asset)
```

### collateralId

```solidity
mapping(address => uint256) collateralId
```

### collateralList

```solidity
address[] collateralList
```

### constructor

```solidity
constructor(address _vaultParameters, address[] assets) public
```

### addCollateral

```solidity
function addCollateral(address asset) public
```

### removeCollateral

```solidity
function removeCollateral(address asset) public
```

### isCollateral

```solidity
function isCollateral(address asset) public view returns (bool)
```

### collaterals

```solidity
function collaterals() external view returns (address[])
```

### collateralsCount

```solidity
function collateralsCount() external view returns (uint256)
```

