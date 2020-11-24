## `VaultManagerUniswapMainAsset`





### `spawned(address asset, address user)`






### `constructor(address payable _vault, address _uniswapOracle)` (public)





### `spawn(address asset, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct mainPriceProof, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Cannot be used for already spawned positions
Token using as main collateral must be whitelisted
Depositing tokens must be pre-approved to vault address
position actually considered as spawned only when usdpAmount > 0


Spawns new positions


### `spawn_Eth(uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Cannot be used for already spawned positions
WETH must be whitelisted as collateral
COL must be pre-approved to vault address
position actually considered as spawned only when usdpAmount > 0


Spawns new positions using ETH


### `depositAndBorrow(address asset, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct mainPriceProof, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Position should be spawned (USDP borrowed from position) to call this method
Depositing tokens must be pre-approved to vault address
Token using as main collateral must be whitelisted


Deposits collaterals and borrows USDP to spawned positions simultaneously


### `depositAndBorrow_Eth(uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Position should be spawned (USDP borrowed from position) to call this method
Depositing tokens must be pre-approved to vault address
Token using as main collateral must be whitelisted


Deposits collaterals and borrows USDP to spawned positions simultaneously


### `withdrawAndRepay(address asset, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct mainPriceProof, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Tx sender must have a sufficient USDP balance to pay the debt


Withdraws collateral and repays specified amount of debt simultaneously


### `withdrawAndRepay_Eth(uint256 ethAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Tx sender must have a sufficient USDP balance to pay the debt


Withdraws collateral and repays specified amount of debt simultaneously converting WETH to ETH


### `repayUsingCol(address asset, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Tx sender must have a sufficient USDP and COL balances and allowances to pay the debt


Repays specified amount of debt paying fee in COL


### `withdrawAndRepayUsingCol(address asset, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct mainPriceProof, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Tx sender must have a sufficient USDP and COL balances and allowances to pay the debt


Withdraws collateral
Repays specified amount of debt paying fee in COL


### `withdrawAndRepayUsingCol_Eth(uint256 ethAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct mainPriceProof, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (public)

Tx sender must have a sufficient USDP and COL balances to pay the debt


Withdraws collateral converting WETH to ETH
Repays specified amount of debt paying fee in COL


### `_depositAndBorrow(address asset, address user, uint256 mainAmount, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct mainPriceProof, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (internal)





### `_depositAndBorrow_Eth(address user, uint256 colAmount, uint256 usdpAmount, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (internal)





### `_ensureCollateralizationTroughProofs(address asset, address user, struct UniswapOracleAbstract.ProofDataStruct mainPriceProof, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (internal)





### `_ensureCollateralizationTroughProofs_Eth(address user, struct UniswapOracleAbstract.ProofDataStruct colPriceProof)` (internal)





### `_ensureCollateralization(address asset, address user, uint256 mainUsdValue_q112, uint256 colUsdValue_q112)` (internal)






### `Join(address asset, address user, uint256 main, uint256 col, uint256 usdp)`



Trigger when joins are happened*

### `Exit(address asset, address user, uint256 main, uint256 col, uint256 usdp)`



Trigger when exits are happened*

