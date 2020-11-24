## `Vault`

Vault is the core of Unit Protocol USDP Stablecoin system
Vault stores and manages collateral funds of all positions and counts debts
Only Vault can manage supply of USDP token
Vault will not be changed/upgraded after initial deployment for the current stablecoin version*




### `constructor(address _parameters, address _col, contract USDP _usdp, address payable _weth)` (public)





### `receive()` (external)





### `update(address asset, address user)` (public)



Updates parameters of the position to the current ones


### `spawn(address asset, address user, uint256 _oracleType)` (external)



Creates new position for user


### `destroy(address asset, address user)` (public)



Clears unused storage variables


### `depositMain(address asset, address user, uint256 amount)` (external)

Tokens must be pre-approved


Adds main collateral to a position


### `depositEth(address user)` (external)



Converts ETH to WETH and adds main collateral to a position


### `withdrawMain(address asset, address user, uint256 amount)` (external)



Withdraws main collateral from a position


### `withdrawEth(address payable user, uint256 amount)` (external)



Withdraws WETH collateral from a position converting WETH to ETH


### `depositCol(address asset, address user, uint256 amount)` (external)

Tokens must be pre-approved


Adds COL token to a position


### `withdrawCol(address asset, address user, uint256 amount)` (external)



Withdraws COL token from a position


### `borrow(address asset, address user, uint256 amount) → uint256` (external)



Increases position's debt and mints USDP token


### `repay(address asset, address user, uint256 amount) → uint256` (external)



Decreases position's debt and burns USDP token


### `chargeFee(address asset, address user, uint256 amount)` (external)



Transfers fee to foundation


### `liquidate(address asset, address positionOwner, address liquidator, uint256 usdCollateralValue)` (external)



Deletes position and transfers collateral to liquidation system


### `changeOracleType(address asset, address user, uint256 newOracleType)` (external)

Only manager can call this function


Changes broken oracle type to the correct one


### `isContract(address account) → bool` (internal)





### `getTotalDebt(address asset, address user) → uint256` (public)



Calculates the total amount of position's debt based on elapsed time


### `calculateFee(address asset, address user, uint256 amount) → uint256` (public)



Calculates the amount of fee based on elapsed time and repayment amount



