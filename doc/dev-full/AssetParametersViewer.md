# Solidity API

## AssetParametersViewer

Views collaterals in one request to save node requests and speed up dapps.

_It makes no sense to clog a node with hundreds of RPC requests and slow a client app/dapp. Since usually
     a huge amount of gas is available to node static calls, we can aggregate asset data in a huge batch on the
     node's side and pull it to the client._

### vaultParameters

```solidity
contract IVaultParameters vaultParameters
```

### vaultManagerParameters

```solidity
contract IVaultManagerParameters vaultManagerParameters
```

### vaultManagerBorrowFeeParameters

```solidity
contract IVaultManagerBorrowFeeParameters vaultManagerBorrowFeeParameters
```

### assetsBooleanParameters

```solidity
contract IAssetsBooleanParameters assetsBooleanParameters
```

### AssetParametersStruct

```solidity
struct AssetParametersStruct {
  address asset;
  uint256 stabilityFee;
  uint256 liquidationFee;
  uint256 initialCollateralRatio;
  uint256 liquidationRatio;
  uint256 liquidationDiscount;
  uint256 devaluationPeriod;
  uint256 tokenDebtLimit;
  uint256[] oracles;
  uint256 minColPercent;
  uint256 maxColPercent;
  uint256 borrowFee;
  bool forceTransferAssetToOwnerOnLiquidation;
  bool forceMoveWrappedAssetPositionOnLiquidation;
}
```

### constructor

```solidity
constructor(address _vaultManagerParameters, address _vaultManagerBorrowFeeParameters, address _assetsBooleanParameters) public
```

### getAssetParameters

```solidity
function getAssetParameters(address asset, uint256 maxOracleTypesToSearch) public view returns (struct AssetParametersViewer.AssetParametersStruct r)
```

Get parameters of one asset

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | asset address |
| maxOracleTypesToSearch | uint256 | since complete list of oracle types is unknown, we'll check types up to this number |

### getMultiAssetParameters

```solidity
function getMultiAssetParameters(address[] assets, uint256 maxOracleTypesToSearch) external view returns (struct AssetParametersViewer.AssetParametersStruct[] r)
```

Get parameters of many assets

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| assets | address[] | asset addresses |
| maxOracleTypesToSearch | uint256 | since complete list of oracle types is unknown, we'll check types up to this number |

