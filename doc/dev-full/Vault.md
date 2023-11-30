# Solidity API

## Vault

Vault is the core of Unit Protocol USDP Stablecoin system
Vault stores and manages collateral funds of all positions and counts debts
Only Vault can manage supply of USDP token
Vault will not be changed/upgraded after initial deployment for the current stablecoin version

### col

```solidity
address col
```

### weth

```solidity
address payable weth
```

### DENOMINATOR_1E5

```solidity
uint256 DENOMINATOR_1E5
```

### DENOMINATOR_1E2

```solidity
uint256 DENOMINATOR_1E2
```

### usdp

```solidity
address usdp
```

### collaterals

```solidity
mapping(address => mapping(address => uint256)) collaterals
```

### colToken

```solidity
mapping(address => mapping(address => uint256)) colToken
```

### debts

```solidity
mapping(address => mapping(address => uint256)) debts
```

### liquidationBlock

```solidity
mapping(address => mapping(address => uint256)) liquidationBlock
```

### liquidationPrice

```solidity
mapping(address => mapping(address => uint256)) liquidationPrice
```

### tokenDebts

```solidity
mapping(address => uint256) tokenDebts
```

### stabilityFee

```solidity
mapping(address => mapping(address => uint256)) stabilityFee
```

### liquidationFee

```solidity
mapping(address => mapping(address => uint256)) liquidationFee
```

### oracleType

```solidity
mapping(address => mapping(address => uint256)) oracleType
```

### lastUpdate

```solidity
mapping(address => mapping(address => uint256)) lastUpdate
```

### notLiquidating

```solidity
modifier notLiquidating(address asset, address user)
```

### constructor

```solidity
constructor(address _parameters, address _col, address _usdp, address payable _weth) public
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _parameters | address | The address of the system parameters |
| _col | address | COL token address |
| _usdp | address | USDP token address |
| _weth | address payable |  |

### receive

```solidity
receive() external payable
```

### update

```solidity
function update(address asset, address user) public
```

_Updates parameters of the position to the current ones_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The owner of a position |

### spawn

```solidity
function spawn(address asset, address user, uint256 _oracleType) external
```

_Creates new position for user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| _oracleType | uint256 | The type of an oracle |

### destroy

```solidity
function destroy(address asset, address user) public
```

_Clears unused storage variables_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |

### depositMain

```solidity
function depositMain(address asset, address user, uint256 amount) external
```

Tokens must be pre-approved

_Adds main collateral to a position_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| amount | uint256 | The amount of tokens to deposit |

### depositEth

```solidity
function depositEth(address user) external payable
```

_Converts ETH to WETH and adds main collateral to a position_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The address of a position's owner |

### withdrawMain

```solidity
function withdrawMain(address asset, address user, uint256 amount) external
```

_Withdraws main collateral from a position_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| amount | uint256 | The amount of tokens to withdraw |

### withdrawEth

```solidity
function withdrawEth(address payable user, uint256 amount) external
```

_Withdraws WETH collateral from a position converting WETH to ETH_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address payable | The address of a position's owner |
| amount | uint256 | The amount of ETH to withdraw |

### depositCol

```solidity
function depositCol(address asset, address user, uint256 amount) external
```

Tokens must be pre-approved

_Adds COL token to a position_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| amount | uint256 | The amount of tokens to deposit |

### withdrawCol

```solidity
function withdrawCol(address asset, address user, uint256 amount) external
```

_Withdraws COL token from a position_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| amount | uint256 | The amount of tokens to withdraw |

### borrow

```solidity
function borrow(address asset, address user, uint256 amount) external returns (uint256)
```

_Increases position's debt and mints USDP token_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| amount | uint256 | The amount of USDP to borrow |

### repay

```solidity
function repay(address asset, address user, uint256 amount) external returns (uint256)
```

_Decreases position's debt and burns USDP token_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| amount | uint256 | The amount of USDP to repay |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | updated debt of a position |

### chargeFee

```solidity
function chargeFee(address asset, address user, uint256 amount) external
```

_Transfers fee to foundation_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the fee asset |
| user | address | The address to transfer funds from |
| amount | uint256 | The amount of asset to transfer |

### triggerLiquidation

```solidity
function triggerLiquidation(address asset, address positionOwner, uint256 initialPrice) external
```

_Deletes position and transfers collateral to liquidation system_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| positionOwner | address | The address of a position's owner |
| initialPrice | uint256 | The starting price of collateral in USDP |

### liquidate

```solidity
function liquidate(address asset, address positionOwner, uint256 mainAssetToLiquidator, uint256 colToLiquidator, uint256 mainAssetToPositionOwner, uint256 colToPositionOwner, uint256 repayment, uint256 penalty, address liquidator) external
```

_Internal liquidation process_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| positionOwner | address | The address of a position's owner |
| mainAssetToLiquidator | uint256 | The amount of main asset to send to a liquidator |
| colToLiquidator | uint256 | The amount of COL to send to a liquidator |
| mainAssetToPositionOwner | uint256 | The amount of main asset to send to a position owner |
| colToPositionOwner | uint256 | The amount of COL to send to a position owner |
| repayment | uint256 | The repayment in USDP |
| penalty | uint256 | The liquidation penalty in USDP |
| liquidator | address | The address of a liquidator |

### changeOracleType

```solidity
function changeOracleType(address asset, address user, uint256 newOracleType) external
```

Only manager can call this function

_Changes broken oracle type to the correct one_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| newOracleType | uint256 | The new type of an oracle |

### getTotalDebt

```solidity
function getTotalDebt(address asset, address user) public view returns (uint256)
```

_Calculates the total amount of position's debt based on elapsed time_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | user debt of a position plus accumulated fee |

### calculateFee

```solidity
function calculateFee(address asset, address user, uint256 amount) public view returns (uint256)
```

_Calculates the amount of fee based on elapsed time and repayment amount_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the main collateral token |
| user | address | The address of a position's owner |
| amount | uint256 | The repayment amount |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | fee amount |

