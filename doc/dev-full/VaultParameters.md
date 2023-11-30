# Solidity API

## VaultParameters

### stabilityFee

```solidity
mapping(address => uint256) stabilityFee
```

### liquidationFee

```solidity
mapping(address => uint256) liquidationFee
```

### tokenDebtLimit

```solidity
mapping(address => uint256) tokenDebtLimit
```

### canModifyVault

```solidity
mapping(address => bool) canModifyVault
```

### isManager

```solidity
mapping(address => bool) isManager
```

### isOracleTypeEnabled

```solidity
mapping(uint256 => mapping(address => bool)) isOracleTypeEnabled
```

### vault

```solidity
address payable vault
```

### foundation

```solidity
address foundation
```

### constructor

```solidity
constructor(address payable _vault, address _foundation) public
```

The address for an Ethereum contract is deterministically computed from the address of its creator (sender)
and how many transactions the creator has sent (nonce). The sender and nonce are RLP encoded and then
hashed with Keccak-256.
Therefore, the Vault address can be pre-computed and passed as an argument before deployment.

### setManager

```solidity
function setManager(address who, bool permit) external
```

Only manager is able to call this function

_Grants and revokes manager's status of any address_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| who | address | The target address |
| permit | bool | The permission flag |

### setFoundation

```solidity
function setFoundation(address newFoundation) external
```

Only manager is able to call this function

_Sets the foundation address_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newFoundation | address | The new foundation address |

### setCollateral

```solidity
function setCollateral(address asset, uint256 stabilityFeeValue, uint256 liquidationFeeValue, uint256 usdpLimit, uint256[] oracles) external
```

Only manager is able to call this function

_Sets ability to use token as the main collateral_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| stabilityFeeValue | uint256 | The percentage of the year stability fee (3 decimals) |
| liquidationFeeValue | uint256 | The liquidation fee percentage (0 decimals) |
| usdpLimit | uint256 | The USDP token issue limit |
| oracles | uint256[] | The enables oracle types |

### setVaultAccess

```solidity
function setVaultAccess(address who, bool permit) external
```

Only manager is able to call this function

_Sets a permission for an address to modify the Vault_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| who | address | The target address |
| permit | bool | The permission flag |

### setStabilityFee

```solidity
function setStabilityFee(address asset, uint256 newValue) public
```

Only manager is able to call this function

_Sets the percentage of the year stability fee for a particular collateral_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| newValue | uint256 | The stability fee percentage (3 decimals) |

### setLiquidationFee

```solidity
function setLiquidationFee(address asset, uint256 newValue) public
```

Only manager is able to call this function

_Sets the percentage of the liquidation fee for a particular collateral_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| newValue | uint256 | The liquidation fee percentage (0 decimals) |

### setOracleType

```solidity
function setOracleType(uint256 _type, address asset, bool enabled) public
```

Only manager is able to call this function

_Enables/disables oracle types_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _type | uint256 | The type of the oracle |
| asset | address | The address of the main collateral token |
| enabled | bool | The control flag |

### setTokenDebtLimit

```solidity
function setTokenDebtLimit(address asset, uint256 limit) public
```

Only manager is able to call this function

_Sets USDP limit for a specific collateral_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| limit | uint256 | The limit number |

