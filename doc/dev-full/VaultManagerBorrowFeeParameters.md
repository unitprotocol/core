# Solidity API

## VaultManagerBorrowFeeParameters

### BASIS_POINTS_IN_1

```solidity
uint256 BASIS_POINTS_IN_1
```

1 = 100% = 10000 basis points

### AssetBorrowFeeParams

```solidity
struct AssetBorrowFeeParams {
  bool enabled;
  uint16 feeBasisPoints;
}
```

### assetBorrowFee

```solidity
mapping(address => struct VaultManagerBorrowFeeParameters.AssetBorrowFeeParams) assetBorrowFee
```

### baseBorrowFeeBasisPoints

```solidity
uint16 baseBorrowFeeBasisPoints
```

### feeReceiver

```solidity
address feeReceiver
```

Borrow fee receiver

### AssetBorrowFeeParamsEnabled

```solidity
event AssetBorrowFeeParamsEnabled(address asset, uint16 feeBasisPoints)
```

### AssetBorrowFeeParamsDisabled

```solidity
event AssetBorrowFeeParamsDisabled(address asset)
```

### nonZeroAddress

```solidity
modifier nonZeroAddress(address addr)
```

### correctFee

```solidity
modifier correctFee(uint16 fee)
```

### constructor

```solidity
constructor(address _vaultParameters, uint16 _baseBorrowFeeBasisPoints, address _feeReceiver) public
```

### setFeeReceiver

```solidity
function setFeeReceiver(address newFeeReceiver) external
```

Sets the borrow fee receiver. Only manager is able to call this function

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newFeeReceiver | address | The address of fee receiver |

### setBaseBorrowFee

```solidity
function setBaseBorrowFee(uint16 newBaseBorrowFeeBasisPoints) external
```

Sets the base borrow fee in basis points (1bp = 0.01% = 0.0001). Only manager is able to call this function

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newBaseBorrowFeeBasisPoints | uint16 | The borrow fee in basis points |

### setAssetBorrowFee

```solidity
function setAssetBorrowFee(address asset, bool newEnabled, uint16 newFeeBasisPoints) external
```

Sets the borrow fee for a particular collateral in basis points (1bp = 0.01% = 0.0001). Only manager is able to call this function

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| newEnabled | bool | Is custom fee enabled for asset |
| newFeeBasisPoints | uint16 | The borrow fee in basis points |

### getBorrowFee

```solidity
function getBorrowFee(address asset) public view returns (uint16 feeBasisPoints)
```

Returns borrow fee for particular collateral in basis points (1bp = 0.01% = 0.0001)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| feeBasisPoints | uint16 | The borrow fee in basis points |

### calcBorrowFeeAmount

```solidity
function calcBorrowFeeAmount(address asset, uint256 usdpAmount) external view returns (uint256)
```

Returns borrow fee for usdp amount for particular collateral

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| usdpAmount | uint256 |  |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The borrow fee |

