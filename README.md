# Unit Protocol

#### [Contract addresses](CONTRACTS.md)

[Unit Protocol](https://unit.xyz/) is a decentralized protocol that allows you to mint stablecoin [USDP](contracts/USDP.sol) using a variety of tokens as collateral. See the [docs](https://docs.unit.xyz/).


## Oracles

#### [Oracle contracts](CONTRACTS.md#Oracles)

The most important part of the onchain stablecoin protocol is the oracles that allow the system to measure asset values on the fly. Unit Protocol stablecoin system currently uses the following types of onchain oracles:

- Direct wrappers for existing [Chainlink feeds](https://data.chain.link/)
- Custom wrappers for DeFi primitives (aka bearing assets) using Chainlink-based wrappers
- [Keydonix-based](https://github.com/keydonix/uniswap-oracle) time-weighted average price (TWAP) oracle implementation that uses a window of [100; 255] blocks for price calculation
- [Keep3rOracle-based](https://github.com/keep3r-network/keep3r.network/blob/master/contracts/jobs/UniswapV2Oracle.sol) time-weighted average price (TWAP) oracle implementation that uses a window of 1.5 - 2.5h for price calculation
- Oracles for different LP tokens

See the full current list of contracts here: [Oracle contracts](CONTRACTS.md#Oracles). Info about concrete oracle used for collateral is listed on collateral page on https://unit.xyz/
