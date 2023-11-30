# Solidity API

## USDP

_ERC20 token_

### name

```solidity
string name
```

### symbol

```solidity
string symbol
```

### version

```solidity
string version
```

### decimals

```solidity
uint8 decimals
```

### totalSupply

```solidity
uint256 totalSupply
```

### balanceOf

```solidity
mapping(address => uint256) balanceOf
```

### allowance

```solidity
mapping(address => mapping(address => uint256)) allowance
```

### Approval

```solidity
event Approval(address owner, address spender, uint256 value)
```

_Trigger on any successful call to approve(address spender, uint amount)_

### Transfer

```solidity
event Transfer(address from, address to, uint256 value)
```

_Trigger when tokens are transferred, including zero value transfers_

### constructor

```solidity
constructor(address _parameters) public
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _parameters | address | The address of system parameters contract |

### mint

```solidity
function mint(address to, uint256 amount) external
```

Only Vault can mint USDP

_Mints 'amount' of tokens to address 'to', and MUST fire the
Transfer event_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address | The address of the recipient |
| amount | uint256 | The amount of token to be minted |

### burn

```solidity
function burn(uint256 amount) external
```

Only manager can burn tokens from manager's balance

_Burns 'amount' of tokens, and MUST fire the Transfer event_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | The amount of token to be burned |

### burn

```solidity
function burn(address from, uint256 amount) external
```

Only Vault can burn tokens from any balance

_Burns 'amount' of tokens from 'from' address, and MUST fire the Transfer event_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | The address of the balance owner |
| amount | uint256 | The amount of token to be burned |

### transfer

```solidity
function transfer(address to, uint256 amount) external returns (bool)
```

_Transfers 'amount' of tokens to address 'to', and MUST fire the Transfer event. The
function SHOULD throw if the _from account balance does not have enough tokens to spend._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address | The address of the recipient |
| amount | uint256 | The amount of token to be transferred |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) public returns (bool)
```

_Transfers 'amount' of tokens from address 'from' to address 'to', and MUST fire the
Transfer event_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | The address of the sender |
| to | address | The address of the recipient |
| amount | uint256 | The amount of token to be transferred |

### approve

```solidity
function approve(address spender, uint256 amount) external returns (bool)
```

_Allows 'spender' to withdraw from your account multiple times, up to the 'amount' amount. If
this function is called again it overwrites the current allowance with 'amount'._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| spender | address | The address of the account able to transfer the tokens |
| amount | uint256 | The amount of tokens to be approved for transfer |

### increaseAllowance

```solidity
function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool)
```

_Atomically increases the allowance granted to `spender` by the caller.

This is an alternative to `approve` that can be used as a mitigation for
problems described in `IERC20.approve`.

Emits an `Approval` event indicating the updated allowance.

Requirements:

- `spender` cannot be the zero address._

### decreaseAllowance

```solidity
function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool)
```

_Atomically decreases the allowance granted to `spender` by the caller.

This is an alternative to `approve` that can be used as a mitigation for
problems described in `IERC20.approve`.

Emits an `Approval` event indicating the updated allowance.

Requirements:

- `spender` cannot be the zero address.
- `spender` must have allowance for the caller of at least
`subtractedValue`._

### _approve

```solidity
function _approve(address owner, address spender, uint256 amount) internal virtual
```

### _burn

```solidity
function _burn(address from, uint256 amount) internal virtual
```

