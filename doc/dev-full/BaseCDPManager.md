# Solidity API

## BaseCDPManager

_all common logic should be moved here in future_

### vault

```solidity
contract IVault vault
```

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

### oracleRegistry

```solidity
contract IOracleRegistry oracleRegistry
```

### cdpRegistry

```solidity
contract ICDPRegistry cdpRegistry
```

### swappersRegistry

```solidity
contract ISwappersRegistry swappersRegistry
```

### usdp

```solidity
contract IERC20 usdp
```

### Q112

```solidity
uint256 Q112
```

### DENOMINATOR_1E5

```solidity
uint256 DENOMINATOR_1E5
```

### Join

```solidity
event Join(address asset, address owner, uint256 main, uint256 usdp)
```

_Trigger when joins are happened_

### JoinWithLeverage

```solidity
event JoinWithLeverage(address asset, address owner, uint256 userAssetAmount, uint256 swappedAssetAmount, uint256 usdp)
```

_Log joins with leverage_

### Exit

```solidity
event Exit(address asset, address owner, uint256 main, uint256 usdp)
```

_Trigger when exits are happened_

### ExitWithDeleverage

```solidity
event ExitWithDeleverage(address asset, address owner, uint256 assetToUser, uint256 assetToSwap, uint256 usdp)
```

_Log exit with deleverage_

### LiquidationTriggered

```solidity
event LiquidationTriggered(address asset, address owner)
```

_Trigger when liquidations are initiated_

### checkpoint

```solidity
modifier checkpoint(address asset, address owner)
```

### constructor

```solidity
constructor(address _vaultManagerParameters, address _vaultManagerBorrowFeeParameters, address _oracleRegistry, address _cdpRegistry, address _swappersRegistry) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _vaultManagerParameters | address | The address of the contract with Vault manager parameters |
| _vaultManagerBorrowFeeParameters | address | The address of the vault manager borrow fee parameters |
| _oracleRegistry | address | The address of the oracle registry |
| _cdpRegistry | address | The address of the CDP registry |
| _swappersRegistry | address | The address of the swappers registry |

### _chargeBorrowFee

```solidity
function _chargeBorrowFee(address asset, address user, uint256 usdpAmount) internal returns (uint256 borrowFee)
```

Charge borrow fee if needed

### _repay

```solidity
function _repay(address asset, address owner, uint256 usdpAmount) internal
```

### liquidationPrice_q112

```solidity
function liquidationPrice_q112(address asset, address owner) external view returns (uint256)
```

_Calculates liquidation price_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| owner | address | The owner of the position |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Q112-encoded liquidation price |

### _calcPrincipal

```solidity
function _calcPrincipal(address asset, address owner, uint256 repayment) internal view returns (uint256)
```

_Returned asset amount + charged stability fee on this amount = repayment (in fact <= repayment bcs of rounding error)_

### _isLiquidatablePosition

```solidity
function _isLiquidatablePosition(address asset, address owner, uint256 usdValue_q112) internal view returns (bool)
```

_Determines whether a position is liquidatable_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| owner | address | The owner of the position |
| usdValue_q112 | uint256 | Q112-encoded USD value of the collateral |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | boolean value, whether a position is liquidatable |

### _ensureOracle

```solidity
function _ensureOracle(address asset) internal view virtual returns (uint256 oracleType)
```

### _mintUsdp

```solidity
function _mintUsdp(address _asset, address _owner, uint256 _amount) internal returns (uint256 usdpAmountToUser)
```

### _swapUsdpToAssetAndCheck

```solidity
function _swapUsdpToAssetAndCheck(contract ISwapper swapper, address _asset, uint256 _usdpAmountToSwap, uint256 _minSwappedAssetAmount) internal returns (uint256 swappedAssetAmount)
```

### _swapAssetToUsdpAndCheck

```solidity
function _swapAssetToUsdpAndCheck(contract ISwapper swapper, address _asset, uint256 _assetAmountToSwap, uint256 _minSwappedUsdpAmount) internal returns (uint256 swappedUsdpAmount)
```

