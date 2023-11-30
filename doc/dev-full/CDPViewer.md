# Solidity API

## CDPViewer

Views collaterals in one request to save node requests and speed up dapps.

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

### CDP

```solidity
struct CDP {
  uint128 collateral;
  uint128 debt;
  uint256 totalDebt;
  uint32 stabilityFee;
  uint32 lastUpdate;
  uint16 liquidationFee;
  uint16 oracleType;
}
```

### CollateralParameters

```solidity
struct CollateralParameters {
  uint128 tokenDebtLimit;
  uint128 tokenDebt;
  uint32 stabilityFee;
  uint32 liquidationDiscount;
  uint32 devaluationPeriod;
  uint16 liquidationRatio;
  uint16 initialCollateralRatio;
  uint16 liquidationFee;
  uint16 oracleType;
  uint16 borrowFee;
  struct CDPViewer.CDP cdp;
}
```

### TokenDetails

```solidity
struct TokenDetails {
  address[2] lpUnderlyings;
  uint128 balance;
  uint128 totalSupply;
  uint8 decimals;
  address uniswapV2Factory;
  address underlyingToken;
  uint256 underlyingTokenBalance;
  uint256 underlyingTokenTotalSupply;
  uint8 underlyingTokenDecimals;
  address underlyingTokenUniswapV2Factory;
  address[2] underlyingTokenUnderlyings;
}
```

### constructor

```solidity
constructor(address _vaultManagerParameters, address _oracleRegistry, address _vaultManagerBorrowFeeParameters) public
```

### getCollateralParameters

```solidity
function getCollateralParameters(address asset, address owner) public view returns (struct CDPViewer.CollateralParameters r)
```

Get parameters of one asset

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | asset address |
| owner | address | owner address |

### getTokenDetails

```solidity
function getTokenDetails(address asset, address owner) public view returns (struct CDPViewer.TokenDetails r)
```

Get details of one token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | token address |
| owner | address | owner address |

### getMultiCollateralParameters

```solidity
function getMultiCollateralParameters(address[] assets, address owner) external view returns (struct CDPViewer.CollateralParameters[] r)
```

Get parameters of many collaterals

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| assets | address[] | asset addresses |
| owner | address | owner address |

### getMultiTokenDetails

```solidity
function getMultiTokenDetails(address[] assets, address owner) external view returns (struct CDPViewer.TokenDetails[] r)
```

Get details of many token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| assets | address[] | token addresses |
| owner | address | owner address |

