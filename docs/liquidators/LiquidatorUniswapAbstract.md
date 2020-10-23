## `LiquidatorUniswapAbstract`



Manages liquidation process*


### `constructor(address payable _vault, uint256 _oracleType)` (public)





### `liquidate(address asset, address user, struct UniswapOracleAbstract.ProofDataStruct assetProof, struct UniswapOracleAbstract.ProofDataStruct colProof)` (external)



Liquidates position


### `isLiquidatablePosition(address asset, address user, uint256 mainUsdValue_q112, uint256 colUsdValue_q112) → bool` (public)



Determines whether a position is liquidatable


### `UR(uint256 mainUsdValue, uint256 colUsdValue, uint256 debt) → uint256` (public)



Calculates position's utilization ratio


### `LR(address asset, uint256 mainUsdValue, uint256 colUsdValue) → uint256` (public)



Calculates position's liquidation ratio based on collateral proportion



### `Liquidation(address token, address user)`



Trigger when liquidations are happened*

