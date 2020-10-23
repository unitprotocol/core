## `VaultManagerUniswapPoolToken`





### `spawned(address asset, address user)`






### `constructor(address payable _vault, address _uniswapOracle)` (public)





### `spawn(address asset, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct underlyingProof, struct UniswapOracleAbstract.ProofDataStruct colProof)` (public)

Cannot be used for already spawned positions
Token using as main collateral must be whitelisted
Depositing tokens must be pre-approved to vault address
position actually considered as spawned only when usdpAmount > 0


Spawns new positions
Adds collaterals to non-spawned positions


### `depositAndBorrow(address asset, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct underlyingProof, struct UniswapOracleAbstract.ProofDataStruct colProof)` (public)

Position should be spawned (USDP borrowed from position) to call this method
Depositing tokens must be pre-approved to vault address
Token using as main collateral must be whitelisted


Deposits collaterals to spawned positions
Borrows USDP


### `withdrawAndRepay(address asset, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct underlyingProof, struct UniswapOracleAbstract.ProofDataStruct colProof)` (public)

Tx sender must have a sufficient USDP balance to pay the debt


Withdraws collateral
Repays specified amount of debt


### `repayUsingCol(address asset, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Tx sender must have a sufficient USDP and COL balances and allowances to pay the debt


Repays specified amount of debt paying fee in COL


### `withdrawAndRepayUsingCol(address asset, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct underlyingProof, struct UniswapOracleAbstract.ProofDataStruct colProof)` (public)

Tx sender must have a sufficient USDP and COL balances to pay the debt


Withdraws collateral
Repays specified amount of debt paying fee in COL


### `_depositAndBorrow(address asset, address user, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct underlyingProof, struct UniswapOracleAbstract.ProofDataStruct colProof)` (internal)





### `_ensureCollateralizationTroughProofs(address asset, address user, struct UniswapOracleAbstract.ProofDataStruct underlyingProof, struct UniswapOracleAbstract.ProofDataStruct colProof)` (internal)





### `_ensureCollateralization(address asset, address user, uint256 mainUsdValue_q112, uint256 colUsdValue_q112)` (internal)






### `Join(address asset, address user, uint256 main, uint256 col, uint256 usdp)`



Trigger when joins are happened*

### `Exit(address asset, address user, uint256 main, uint256 col, uint256 usdp)`



Trigger when exits are happened*

