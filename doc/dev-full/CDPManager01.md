# Solidity API

## CDPManager01

### WETH

```solidity
address payable WETH
```

### constructor

```solidity
constructor(address _vaultManagerParameters, address _vaultManagerBorrowFeeParameters, address _oracleRegistry, address _cdpRegistry, address _swappersRegistry) public
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _vaultManagerParameters | address | The address of the contract with Vault manager parameters |
| _vaultManagerBorrowFeeParameters | address | The address of the vault manager borrow fee parameters |
| _oracleRegistry | address | The address of the oracle registry |
| _cdpRegistry | address | The address of the CDP registry |
| _swappersRegistry | address | The address of the swappers registry |

### receive

```solidity
receive() external payable
```

### join

```solidity
function join(address asset, uint256 assetAmount, uint256 usdpAmount) public
```

Depositing tokens must be pre-approved to Vault address
Borrow fee in USDP tokens must be pre-approved to CDP manager address
position actually considered as spawned only when debt > 0

_Deposits collateral and/or borrows USDP_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| assetAmount | uint256 | The amount of the collateral to deposit |
| usdpAmount | uint256 | The amount of USDP token to borrow |

### join_Eth

```solidity
function join_Eth(uint256 usdpAmount) external payable
```

_Deposits ETH and/or borrows USDP_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| usdpAmount | uint256 | The amount of USDP token to borrow |

### joinWithLeverage

```solidity
function joinWithLeverage(address asset, contract ISwapper swapper, uint256 assetAmount, uint256 usdpAmount, uint256 minSwappedAssetAmount) public
```

Deposit asset with leverage. All usdp will be swapped to asset and deposited with user's asset
For leverage L user must pass usdpAmount = (L - 1) * assetAmount * price
User must:
 - preapprove asset to vault: to deposit wrapped asset to vault
 - preapprove USDP to swapper: swap USDP to additional asset
 - preapprove USDP to CDPManager: to charge borrow (issuance) fee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| swapper | contract ISwapper | The address of swapper (for swap usdp->asset) |
| assetAmount | uint256 | The amount of the collateral to deposit |
| usdpAmount | uint256 | The amount of USDP token to borrow |
| minSwappedAssetAmount | uint256 | min asset amount which user must get after swap usdpAmount (in case of slippage) |

### wrapAndJoin

```solidity
function wrapAndJoin(contract IWrappedAsset wrappedAsset, uint256 assetAmount, uint256 usdpAmount) external
```

Deposit asset, stake it if supported, mint wrapped asset and lock it, borrow USDP
User must:
 - preapprove token to wrappedAsset: to deposit asset to wrapped asset for wrapping
 - preapprove wrapped token to vault: to deposit wrapped asset to vault
 - preapprove USDP to CDPManager: to charge borrow (issuance) fee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| wrappedAsset | contract IWrappedAsset | Address of wrapped asset |
| assetAmount | uint256 | The amount of the collateral to deposit |
| usdpAmount | uint256 | The amount of USDP token to borrow |

### wrapAndJoinWithLeverage

```solidity
function wrapAndJoinWithLeverage(contract IWrappedAsset wrappedAsset, contract ISwapper swapper, uint256 assetAmount, uint256 usdpAmount, uint256 minSwappedAssetAmount) public
```

Wrap and deposit asset with leverage. All usdp will be swapped to asset and deposited with user's asset
For leverage L user must pass usdpAmount = (L - 1) * assetAmount * price
User must:
 - preapprove token to wrappedAsset: to deposit asset to wrapped asset for wrapping
 - preapprove wrapped token to vault: to deposit wrapped asset to vault
 - preapprove USDP to swapper: swap USDP to additional asset
 - preapprove USDP to CDPManager: to charge borrow (issuance) fee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| wrappedAsset | contract IWrappedAsset | The address of wrapped asset |
| swapper | contract ISwapper | The address of swapper (for swap usdp->asset) |
| assetAmount | uint256 | The amount of the collateral to deposit |
| usdpAmount | uint256 | The amount of USDP token to borrow |
| minSwappedAssetAmount | uint256 | min asset amount which user must get after swap usdpAmount (in case of slippage) |

### exit

```solidity
function exit(address asset, uint256 assetAmount, uint256 usdpAmount) public returns (uint256)
```

Tx sender must have a sufficient USDP balance to pay the debt

_Withdraws collateral and repays specified amount of debt_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| assetAmount | uint256 | The amount of the collateral to withdraw |
| usdpAmount | uint256 | The amount of USDP to repay |

### exitWithDeleverage

```solidity
function exitWithDeleverage(address asset, contract ISwapper swapper, uint256 assetAmountToUser, uint256 assetAmountToSwap, uint256 minSwappedUsdpAmount) public returns (uint256)
```

Withdraws collateral and repay debt without USDP needed. assetAmountToSwap would be swaped to USDP internally
User must:
 - preapprove USDP to vault: pay stability fee
 - preapprove asset to swapper: swap asset to USDP

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| swapper | contract ISwapper | The address of swapper (for swap asset->usdp) |
| assetAmountToUser | uint256 | The amount of the collateral to withdraw |
| assetAmountToSwap | uint256 | The amount of the collateral to swap to USDP |
| minSwappedUsdpAmount | uint256 | min USDP amount which user must get after swap assetAmountToSwap (in case of slippage) |

### exit_targetRepayment

```solidity
function exit_targetRepayment(address asset, uint256 assetAmount, uint256 repayment) external returns (uint256)
```

Repayment is the sum of the principal and interest

_Withdraws collateral and repays specified amount of debt_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| assetAmount | uint256 | The amount of the collateral to withdraw |
| repayment | uint256 | The target repayment amount |

### exit_Eth

```solidity
function exit_Eth(uint256 ethAmount, uint256 usdpAmount) public returns (uint256)
```

Withdraws WETH and converts to ETH

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ethAmount | uint256 | ETH amount to withdraw |
| usdpAmount | uint256 | The amount of USDP token to repay |

### exit_Eth_targetRepayment

```solidity
function exit_Eth_targetRepayment(uint256 ethAmount, uint256 repayment) external returns (uint256)
```

Repayment is the sum of the principal and interest
Withdraws WETH and converts to ETH

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ethAmount | uint256 | ETH amount to withdraw |
| repayment | uint256 | The target repayment amount |

### unwrapAndExit

```solidity
function unwrapAndExit(contract IWrappedAsset wrappedAsset, uint256 assetAmount, uint256 usdpAmount) public returns (uint256)
```

Withdraws wrapped asset and unwrap it, repays specified amount of debt

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| wrappedAsset | contract IWrappedAsset | Address of wrapped asset |
| assetAmount | uint256 | The amount of the collateral to withdrae |
| usdpAmount | uint256 | The amount of USDP token to repay |

### unwrapAndExitTargetRepayment

```solidity
function unwrapAndExitTargetRepayment(contract IWrappedAsset wrappedAsset, uint256 assetAmount, uint256 repayment) public returns (uint256)
```

Withdraws wrapped asset and unwrap it, repays specified amount of debt
Repayment is the sum of the principal and interest

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| wrappedAsset | contract IWrappedAsset | Address of wrapped asset |
| assetAmount | uint256 | The amount of the collateral to withdrae |
| repayment | uint256 | The amount of USDP token to repay |

### unwrapAndExitWithDeleverage

```solidity
function unwrapAndExitWithDeleverage(contract IWrappedAsset wrappedAsset, contract ISwapper swapper, uint256 assetAmountToUser, uint256 assetAmountToSwap, uint256 minSwappedUsdpAmount) public returns (uint256)
```

Withdraws asset and repay debt without USDP needed. assetAmountToSwap would be swaped to USDP internally
User must:
 - preapprove USDP to vault: pay stability fee
 - preapprove asset (underlying token of wrapped asset) to swapper: swap asset to USDP

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| wrappedAsset | contract IWrappedAsset | The address of the wrapped asset |
| swapper | contract ISwapper | The address of swapper (for swap asset->usdp) |
| assetAmountToUser | uint256 | The amount of the collateral to withdraw |
| assetAmountToSwap | uint256 | The amount of the collateral to swap to USDP |
| minSwappedUsdpAmount | uint256 | min USDP amount which user must get after swap assetAmountToSwap (in case of slippage) |

### _joinWithLeverage

```solidity
function _joinWithLeverage(address asset, address tokenToSwap, bool isWrappedAsset, contract ISwapper swapper, uint256 assetAmount, uint256 usdpAmount, uint256 minSwappedAssetAmount) internal
```

### _exitWithDeleverage

```solidity
function _exitWithDeleverage(address asset, address tokenToSwap, bool isWrappedAsset, contract ISwapper swapper, uint256 assetAmountToUser, uint256 assetAmountToSwap, uint256 minSwappedUsdpAmount) internal returns (uint256)
```

### _ensurePositionCollateralization

```solidity
function _ensurePositionCollateralization(address asset, address owner) internal view
```

### triggerLiquidation

```solidity
function triggerLiquidation(address asset, address owner) external
```

_Triggers liquidation of a position_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral token of a position |
| owner | address | The owner of the position |

### getCollateralUsdValue_q112

```solidity
function getCollateralUsdValue_q112(address asset, address owner) public view returns (uint256)
```

### isLiquidatablePosition

```solidity
function isLiquidatablePosition(address asset, address owner) external view returns (bool)
```

_Determines whether a position is liquidatable_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| owner | address | The owner of the position |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | boolean value, whether a position is liquidatable |

### utilizationRatio

```solidity
function utilizationRatio(address asset, address owner) public view returns (uint256)
```

_Calculates current utilization ratio_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the collateral |
| owner | address | The owner of the position |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | utilization ratio |

