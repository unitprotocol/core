## `USDP`



ERC20 token*


### `constructor(address _parameters)` (public)





### `mint(address to, uint256 amount)` (external)

Only Vault can mint USDP


Mints 'amount' of tokens to address 'to', and MUST fire the
Transfer event


### `burn(uint256 amount)` (external)

Only manager can burn tokens from manager's balance


Burns 'amount' of tokens, and MUST fire the Transfer event


### `burn(address from, uint256 amount)` (external)

Only Vault can burn tokens from any balance


Burns 'amount' of tokens from 'from' address, and MUST fire the Transfer event


### `transfer(address to, uint256 amount) → bool` (external)



Transfers 'amount' of tokens to address 'to', and MUST fire the Transfer event. The
function SHOULD throw if the _from account balance does not have enough tokens to spend.


### `transferFrom(address from, address to, uint256 amount) → bool` (public)



Transfers 'amount' of tokens from address 'from' to address 'to', and MUST fire the
Transfer event


### `approve(address spender, uint256 amount) → bool` (external)



Allows 'spender' to withdraw from your account multiple times, up to the 'amount' amount. If
this function is called again it overwrites the current allowance with 'amount'.


### `increaseAllowance(address spender, uint256 addedValue) → bool` (public)



Atomically increases the allowance granted to `spender` by the caller.
This is an alternative to `approve` that can be used as a mitigation for
problems described in `IERC20.approve`.
Emits an `Approval` event indicating the updated allowance.
Requirements:
- `spender` cannot be the zero address.

### `decreaseAllowance(address spender, uint256 subtractedValue) → bool` (public)



Atomically decreases the allowance granted to `spender` by the caller.
This is an alternative to `approve` that can be used as a mitigation for
problems described in `IERC20.approve`.
Emits an `Approval` event indicating the updated allowance.
Requirements:
- `spender` cannot be the zero address.
- `spender` must have allowance for the caller of at least
`subtractedValue`.

### `_approve(address owner, address spender, uint256 amount)` (internal)





### `_burn(address from, uint256 amount)` (internal)






### `Approval(address owner, address spender, uint256 value)`



Trigger on any successful call to approve(address spender, uint amount)*

### `Transfer(address from, address to, uint256 value)`



Trigger when tokens are transferred, including zero value transfers*

