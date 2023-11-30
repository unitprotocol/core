# Solidity API

## ParametersBatchUpdater

### vaultManagerParameters

```solidity
contract IVaultManagerParameters vaultManagerParameters
```

### oracleRegistry

```solidity
contract IOracleRegistry oracleRegistry
```

### collateralRegistry

```solidity
contract ICollateralRegistry collateralRegistry
```

### BEARING_ASSET_ORACLE_TYPE

```solidity
uint256 BEARING_ASSET_ORACLE_TYPE
```

### constructor

```solidity
constructor(address _vaultManagerParameters, address _oracleRegistry, address _collateralRegistry) public
```

### setManagers

```solidity
function setManagers(address[] who, bool[] permit) external
```

Only manager is able to call this function

_Grants and revokes manager's status_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| who | address[] | The array of target addresses |
| permit | bool[] | The array of permission flags |

### setVaultAccesses

```solidity
function setVaultAccesses(address[] who, bool[] permit) external
```

Only manager is able to call this function

_Sets a permission for provided addresses to modify the Vault_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| who | address[] | The array of target addresses |
| permit | bool[] | The array of permission flags |

### setStabilityFees

```solidity
function setStabilityFees(address[] assets, uint256[] newValues) public
```

Only manager is able to call this function

_Sets the percentage of the year stability fee for a particular collateral_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| assets | address[] | The array of addresses of the main collateral tokens |
| newValues | uint256[] | The array of stability fee percentages (3 decimals) |

### setLiquidationFees

```solidity
function setLiquidationFees(address[] assets, uint256[] newValues) public
```

Only manager is able to call this function

_Sets the percentages of the liquidation fee for provided collaterals_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| assets | address[] | The array of addresses of the main collateral tokens |
| newValues | uint256[] | The array of liquidation fee percentages (0 decimals) |

### setOracleTypes

```solidity
function setOracleTypes(uint256[] _types, address[] assets, bool[] flags) public
```

Only manager is able to call this function

_Enables/disables oracle types_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _types | uint256[] | The array of types of the oracles |
| assets | address[] | The array of addresses of the main collateral tokens |
| flags | bool[] | The array of control flags |

### setTokenDebtLimits

```solidity
function setTokenDebtLimits(address[] assets, uint256[] limits) public
```

Only manager is able to call this function

_Sets USDP limits for a provided collaterals_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| assets | address[] | The addresses of the main collateral tokens |
| limits | uint256[] | The borrow USDP limits |

### changeOracleTypes

```solidity
function changeOracleTypes(address[] assets, address[] users, uint256[] oracleTypes) public
```

### setInitialCollateralRatios

```solidity
function setInitialCollateralRatios(address[] assets, uint256[] values) public
```

### setLiquidationRatios

```solidity
function setLiquidationRatios(address[] assets, uint256[] values) public
```

### setLiquidationDiscounts

```solidity
function setLiquidationDiscounts(address[] assets, uint256[] values) public
```

### setDevaluationPeriods

```solidity
function setDevaluationPeriods(address[] assets, uint256[] values) public
```

### setOracleTypesInRegistry

```solidity
function setOracleTypesInRegistry(uint256[] oracleTypes, address[] oracles) public
```

### setOracleTypesToAssets

```solidity
function setOracleTypesToAssets(address[] assets, uint256[] oracleTypes) public
```

### setOracleTypesToAssetsBatch

```solidity
function setOracleTypesToAssetsBatch(address[][] assets, uint256[] oracleTypes) public
```

### setUnderlyings

```solidity
function setUnderlyings(address[] bearings, address[] underlyings) public
```

### setCollaterals

```solidity
function setCollaterals(address[] assets, uint256 stabilityFeeValue, uint256 liquidationFeeValue, uint256 initialCollateralRatioValue, uint256 liquidationRatioValue, uint256 liquidationDiscountValue, uint256 devaluationPeriodValue, uint256 usdpLimit, uint256[] oracles) external
```

### setCollateralAddresses

```solidity
function setCollateralAddresses(address[] assets, bool add) external
```

