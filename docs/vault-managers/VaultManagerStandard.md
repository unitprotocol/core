## `VaultManagerStandard`






### `constructor(address payable _vault)` (public)





### `deposit(address asset, uint256 mainAmount, uint256 colAmount)` (public)

Depositing tokens must be pre-approved to vault address
Token using as main collateral must be whitelisted


Deposits collaterals


### `deposit_Eth(uint256 colAmount)` (public)

COL token must be pre-approved to vault address (if being deposited)
Token using as main collateral must be whitelisted


Deposits collaterals converting ETH to WETH


### `repay(address asset, uint256 usdpAmount)` (public)

Tx sender must have a sufficient USDP balance to pay the debt


Repays specified amount of debt


### `repayAllAndWithdraw(address asset, uint256 mainAmount, uint256 colAmount)` (external)

Tx sender must have a sufficient USDP balance to pay the debt
Token approwal is NOT needed
Merkle proofs are NOT needed since we don't need to check collateralization (cause there is no debt)


Repays total debt and withdraws collaterals


### `repayAllAndWithdraw_Eth(uint256 ethAmount, uint256 colAmount)` (external)

Tx sender must have a sufficient USDP balance to pay the debt
Token approwal is NOT needed
Merkle proofs are NOT needed since we don't need to check collateralization (cause there is no debt)


Repays total debt and withdraws collaterals


### `_repay(address asset, address user, uint256 usdpAmount)` (internal)






### `Join(address asset, address user, uint256 main, uint256 col, uint256 usdp)`



Trigger when params joins are happened*

### `Exit(address asset, address user, uint256 main, uint256 col, uint256 usdp)`



Trigger when params exits are happened*

