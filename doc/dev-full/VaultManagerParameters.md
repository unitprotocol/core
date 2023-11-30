# Solidity API

## VaultManagerParameters

### minColPercent

```solidity
mapping(address => uint256) minColPercent
```

### maxColPercent

```solidity
mapping(address => uint256) maxColPercent
```

### initialCollateralRatio

```solidity
mapping(address => uint256) initialCollateralRatio
```

### liquidationRatio

```solidity
mapping(address => uint256) liquidationRatio
```

### liquidationDiscount

```solidity
mapping(address => uint256) liquidationDiscount
```

### devaluationPeriod

```solidity
mapping(address => uint256) devaluationPeriod
```

### constructor

```solidity
constructor(address _vaultParameters) public
```

### setCollateral

```solidity
function setCollateral(address asset, uint256 stabilityFeeValue, uint256 liquidationFeeValue, uint256 initialCollateralRatioValue, uint256 liquidationRatioValue, uint256 liquidationDiscountValue, uint256 devaluationPeriodValue, uint256 usdpLimit, uint256[] oracles, uint256 minColP, uint256 maxColP) external
```

Only manager is able to call this function

_Sets ability to use token as the main collateral_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| stabilityFeeValue | uint256 | The percentage of the year stability fee (3 decimals) |
| liquidationFeeValue | uint256 | The liquidation fee percentage (0 decimals) |
| initialCollateralRatioValue | uint256 | The initial collateralization ratio |
| liquidationRatioValue | uint256 | The liquidation ratio |
| liquidationDiscountValue | uint256 | The liquidation discount (3 decimals) |
| devaluationPeriodValue | uint256 | The devaluation period in blocks |
| usdpLimit | uint256 | The USDP token issue limit |
| oracles | uint256[] | The enabled oracles type IDs |
| minColP | uint256 | The min percentage of COL value in position (0 decimals) |
| maxColP | uint256 | The max percentage of COL value in position (0 decimals) |

### setInitialCollateralRatio

```solidity
function setInitialCollateralRatio(address asset, uint256 newValue) public
```

Only manager is able to call this function

_Sets the initial collateral ratio_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| newValue | uint256 | The collateralization ratio (0 decimals) |

### setLiquidationRatio

```solidity
function setLiquidationRatio(address asset, uint256 newValue) public
```

Only manager is able to call this function

_Sets the liquidation ratio_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| newValue | uint256 | The liquidation ratio (0 decimals) |

### setLiquidationDiscount

```solidity
function setLiquidationDiscount(address asset, uint256 newValue) public
```

Only manager is able to call this function

_Sets the liquidation discount_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| newValue | uint256 | The liquidation discount (3 decimals) |

### setDevaluationPeriod

```solidity
function setDevaluationPeriod(address asset, uint256 newValue) public
```

Only manager is able to call this function

_Sets the devaluation period of collateral after liquidation_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| newValue | uint256 | The devaluation period in blocks |

### setColPartRange

```solidity
function setColPartRange(address asset, uint256 min, uint256 max) public
```

Only manager is able to call this function

_Sets the percentage range of the COL token part for specific collateral token_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| min | uint256 | The min percentage (0 decimals) |
| max | uint256 | The max percentage (0 decimals) |

