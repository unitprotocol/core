# Solidity API

## AssetParameters

### PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION

```solidity
uint8 PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION
```

Some assets require a transfer of at least 1 unit of token
to update internal logic related to staking rewards in case of full liquidation

### PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION

```solidity
uint8 PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION
```

Some wrapped assets that require a manual position transfer between users
since `transfer` doesn't do this

### needForceTransferAssetToOwnerOnLiquidation

```solidity
function needForceTransferAssetToOwnerOnLiquidation(uint256 assetBoolParams) internal pure returns (bool)
```

### needForceMoveWrappedAssetPositionOnLiquidation

```solidity
function needForceMoveWrappedAssetPositionOnLiquidation(uint256 assetBoolParams) internal pure returns (bool)
```

