## `ChainlinkedUniswapOracleMainAsset_Mock`



Calculates the USD price of desired tokens*


### `constructor(contract IUniswapV2Factory uniFactory, address weth, contract AggregatorInterface chainlinkAggregator)` (public)





### `assetToUsd(address asset, uint256 amount, struct UniswapOracleAbstract.ProofDataStruct proofData) → uint256` (public)





### `ethToUsd(uint256 ethAmount) → uint256` (public)

ETH/USD price feed from Chainlink, see for more info: https://feeds.chain.link/eth-usd
returns Price of given amount of Ether in USD (0 decimals)*




