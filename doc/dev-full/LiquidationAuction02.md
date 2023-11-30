# Solidity API

## LiquidationAuction02

### vault

```solidity
contract IVault vault
```

### vaultManagerParameters

```solidity
contract IVaultManagerParameters vaultManagerParameters
```

### cdpRegistry

```solidity
contract ICDPRegistry cdpRegistry
```

### assetsBooleanParameters

```solidity
contract IAssetsBooleanParameters assetsBooleanParameters
```

### DENOMINATOR_1E2

```solidity
uint256 DENOMINATOR_1E2
```

### WRAPPED_TO_UNDERLYING_ORACLE_TYPE

```solidity
uint256 WRAPPED_TO_UNDERLYING_ORACLE_TYPE
```

### Buyout

```solidity
event Buyout(address asset, address owner, address buyer, uint256 amount, uint256 price, uint256 penalty)
```

_Trigger when buyouts are happened_

### checkpoint

```solidity
modifier checkpoint(address asset, address owner)
```

### constructor

```solidity
constructor(address _vaultManagerParameters, address _cdpRegistry, address _assetsBooleanParameters) public
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _vaultManagerParameters | address | The address of the contract with Vault manager parameters |
| _cdpRegistry | address | The address of the CDP registry |
| _assetsBooleanParameters | address | The address of the AssetsBooleanParameters |

### buyout

```solidity
function buyout(address asset, address owner) public
```

_Buyouts a position's collateral_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token of a position |
| owner | address | The owner of a position |

### _calcLiquidationParams

```solidity
function _calcLiquidationParams(uint256 depreciationPeriod, uint256 blocksPast, uint256 startingPrice, uint256 debtWithPenalty, uint256 collateralInPosition) internal pure returns (uint256 collateralToBuyer, uint256 collateralToOwner, uint256 price)
```

