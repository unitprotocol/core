### Deposit collateral and borrow USDP

| USDP | Main + COL | Fn                                | Comment                                 | Contract             |
| ---- |:----------:| ---------------------------------:| ---------------------------------------:| --------------------:|
| 0    | \> 0       | deposit()                         |                                         | VaultManagerStandard |
| \> 0 | 0          | depositAndBorrow()                |                                         | VaultManagerUniswap  |
| \> 0 | \> 0       | spawn() <br/> depositAndBorrow()  | *if not spawned yet* <br/> *if spawned* | VaultManagerUniswap  |


### Withdraw collateral and repay USDP

| USDP | Main + COL | Fn                                | Comment                                 | Contract             |
| ---- |:----------:| ---------------------------------:| ---------------------------------------:| --------------------:|
| 0    | \> 0       | withdrawAndRepay()                |                                         | VaultManagerUniswap |
| \> 0 | 0          | repay()                           |                                         | VaultManagerStandard  |
| \> 0 | \> 0       | repayAllAndWithdraw() <br/> withdrawAndRepay()  | *if debt is being fully repaid* <br/> *partially repayment* | VaultManagerStandard <br/> VaultManagerUniswap |
