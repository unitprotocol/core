# Unit Protocol Contracts

### Ecosystem

| Name          | Mainnet       | Bsc       |
| ------------- |:-------------:|:-------------:|
| [WETH(WBNB)](contracts/test-helpers/WETH.sol)      | [0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2](https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code) | [0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c](https://bscscan.com/address/0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c#code) |
| [Uniswap Factory](https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2Factory.sol)      | [0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f](https://etherscan.io/address/0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f#code)      | - |
| [SushiSwap](https://github.com/sushiswap/sushiswap/blob/master/contracts/uniswapv2/UniswapV2Factory.sol) ([PancakeV2](https://github.com/pancakeswap/pancake-swap-core/blob/master/contracts/PancakeFactory.sol)) Factory | [0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac](https://etherscan.io/address/0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac#code)      | [0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73](https://bscscan.com/address/0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73#code)      |
| [ETH/USD](https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd) ([BNB/USD](https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd)) Chainlink Aggregator Proxy     | [0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419](https://etherscan.io/address/0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419#code)      | [0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE](https://bscscan.com/address/0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE#code)      |

### Core

| Name          | Mainnet       | Bsc       |
| ------------- |:-------------:|:-------------:|
| Vault | [0xb1cFF81b9305166ff1EFc49A129ad2AfCd7BCf19](https://etherscan.io/address/0xb1cFF81b9305166ff1EFc49A129ad2AfCd7BCf19#code)      | [0xdacfeed000e12c356fb72ab5089e7dd80ff4dd93](https://bscscan.com/address/0xdacfeed000e12c356fb72ab5089e7dd80ff4dd93#code)      |
| USDP | [0x1456688345527bE1f37E9e627DA0837D6f08C925](https://etherscan.io/address/0x1456688345527bE1f37E9e627DA0837D6f08C925#code)      | [0xdacd011a71f8c9619642bf482f1d4ceb338cffcf](https://bscscan.com/address/0xdacd011a71f8c9619642bf482f1d4ceb338cffcf#code)      |
| VaultParameters      | [0xB46F8CF42e504Efe8BEf895f848741daA55e9f1D](https://etherscan.io/address/0xB46F8CF42e504Efe8BEf895f848741daA55e9f1D#code) | [0x56c7CA666d192332F72a5842E72eED5f59F0fb48](https://bscscan.com/address/0x56c7CA666d192332F72a5842E72eED5f59F0fb48#code) |
| VaultManagerParameters      | [0x203153522B9EAef4aE17c6e99851EE7b2F7D312E](https://etherscan.io/address/0x203153522B9EAef4aE17c6e99851EE7b2F7D312E#code)      | [0x99f2B13C28A4183a5d5e0fe02B1B5aeEe85FAF5A](https://bscscan.com/address/0x99f2B13C28A4183a5d5e0fe02B1B5aeEe85FAF5A#code)      |
| LiquidationAuction02      | [0xaEF1ed4C492BF4C57221bE0706def67813D79955](https://etherscan.io/address/0xaEF1ed4C492BF4C57221bE0706def67813D79955#code)      | [0x754106b2f312c987Dd34161F8b4735392fa93F06](https://bscscan.com/address/0x754106b2f312c987Dd34161F8b4735392fa93F06#code)      |
| CDPManager01      | [0x0e13ab042eC5AB9Fc6F43979406088B9028F66fA](https://etherscan.io/address/0x0e13ab042eC5AB9Fc6F43979406088B9028F66fA#code)      | [0x1337daC01Fc21Fa21D17914f96725f7a7b73868f](https://bscscan.com/address/0x1337daC01Fc21Fa21D17914f96725f7a7b73868f#code)      |
| CDPManager01_Fallback      | [0xaD3617D11f4c1d30603551eA75e9Ace9CB386e15](https://etherscan.io/address/0xaD3617D11f4c1d30603551eA75e9Ace9CB386e15#code)      | - |

### Helpers & Registries

| Name          | Mainnet       | Bsc       |
| ------------- |:-------------:|:-------------:|
| OracleRegistry | [0x75fBFe26B21fd3EA008af0C764949f8214150C8f](https://etherscan.io/address/0x75fBFe26B21fd3EA008af0C764949f8214150C8f#code)      | [0xbea721ACe12e881cb44Dbe9361ffEd9141CE547F](https://bscscan.com/address/0xbea721ACe12e881cb44Dbe9361ffEd9141CE547F#code)      |
| ParametersBatchUpdater | [0x4DD1A6DB148BEcDADAdFC407D23b725eDd3cfB6f](https://etherscan.io/address/0x4DD1A6DB148BEcDADAdFC407D23b725eDd3cfB6f#code)      | - |
| AssetParametersViewer | [0xd51F509Fb80b4fF4D4Bfb4144eEd877F0F499AF6](https://etherscan.io/address/0xd51F509Fb80b4fF4D4Bfb4144eEd877F0F499AF6#code)      | - |
| CollateralRegistry      | [0x3DB39B538Db1123389c77F888a213F1A6dd22EF3](https://etherscan.io/address/0x3DB39B538Db1123389c77F888a213F1A6dd22EF3#code) | [0xA1ad3602697c15113E089C2723c15eBF3038465C](https://bscscan.com/address/0xA1ad3602697c15113E089C2723c15eBF3038465C#code)      |
| CDPRegistry      | [0x1a5Ff58BC3246Eb233fEA20D32b79B5F01eC650c](https://etherscan.io/address/0x1a5Ff58BC3246Eb233fEA20D32b79B5F01eC650c#code)      | [0xE8372dcef80189c0F88631507f6466b3f60E24A4](https://bscscan.com/address/0xE8372dcef80189c0F88631507f6466b3f60E24A4#code)      |
| ForceTransferAssetStore      | [0xF7633FA353E74Edb211B1d22e23c96aE4d7b24C0](https://etherscan.io/address/0xF7633FA353E74Edb211B1d22e23c96aE4d7b24C0#code)      | - |
| PancakeV2Twap | - | [0x11b1bd923f4D0669958e16A511567f540Bc21d2e](https://bscscan.com/address/0x11b1bd923f4D0669958e16A511567f540Bc21d2e#code)      |

### Oracles

| Name          | Type (alias)       | Mainnet       | Bsc       |
| ------------- |:-------------:|:-------------:|:-------------:|
| ChainlinkedKeydonixOracleMainAsset (Uniswap)      | 1 (3) | [0xBFE2e6eCEdFB9CDf0e9dA98AB116D57DdC82D078](https://etherscan.io/address/0xBFE2e6eCEdFB9CDf0e9dA98AB116D57DdC82D078#code)    |
| ChainlinkedKeydonixOraclePoolToken      | 2 (4, 8) | [0x72A2e0D0A201B54DcFB668a46BE99494eFF6D2A8](https://etherscan.io/address/0x72A2e0D0A201B54DcFB668a46BE99494eFF6D2A8#code)      |
| ChainlinkedOracleMainAsset | 5 (3, 7) | [0x54b21C140F5463e1fDa69B934da619eAaa61f1CA](https://etherscan.io/address/0x54b21C140F5463e1fDa69B934da619eAaa61f1CA#code)      |
| BearingAssetOracle      | 9 | [0x190DB945Ae572Ae72E367b549b78C41E211864AB](https://etherscan.io/address/0x190DB945Ae572Ae72E367b549b78C41E211864AB#code)      |
| ChainlinkedKeep3rV1OracleMainAsset | 7 | - | [0x7562FB711173095Bc2d8100C107e6Da639E0F4B0](https://bscscan.com/address/0x7562FB711173095Bc2d8100C107e6Da639E0F4B0#code)      |
| CurveLPOracle      | 10 | [0x0E08d9e1DC22a400EbcA25E9a8f292910fa8fe08](https://etherscan.io/address/0x0E08d9e1DC22a400EbcA25E9a8f292910fa8fe08#code)      |
| WrappedToUnderlyingOracle      | 11 | [0x220Ea780a484c18fd0Ab252014c58299759a1Fbd](https://etherscan.io/address/0x220Ea780a484c18fd0Ab252014c58299759a1Fbd#code)      |
| OraclePoolToken      | 12 (4, 8) | [0x5968Bc303930155d36fA9AeE2B5b0F6D39598434](https://etherscan.io/address/0x5968Bc303930155d36fA9AeE2B5b0F6D39598434#code) |
| ChainlinkedKeydonixOracleMainAsset (Sushiswap)      | 13 (7) | [0x769E35030f5cE160b287Bce0462d46Decf29b6DD](https://etherscan.io/address/0x769E35030f5cE160b287Bce0462d46Decf29b6DD#code)      |
| CyTokenOracle      | 14 | [0x40B743Ca424E3eC7b97f5AD93d2263Ae01DAE1D8](https://etherscan.io/address/0x40B743Ca424E3eC7b97f5AD93d2263Ae01DAE1D8#code)      |
| YvTokenOracle      | 15 | [0x759EB07A8258BcF5590E9303763803DcF264652d](https://etherscan.io/address/0x759EB07A8258BcF5590E9303763803DcF264652d#code)      |
