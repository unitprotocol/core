# Unit Protocol Contracts

### Ecosystem

| Name          | Mainnet       | Bsc       | Fantom        |
| ------------- |:-------------:|:-------------:|:-------------:|
| [Wrapped network token (WETH, WBNB, ...)](contracts/test-helpers/WETH.sol)      | [0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2](https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code) | [0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c](https://bscscan.com/address/0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c#code) | [0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83](https://ftmscan.com/address/0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83) |
| [Uniswap Factory](https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2Factory.sol)      | [0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f](https://etherscan.io/address/0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f#code)      | - | - |
| [SushiSwap](https://github.com/sushiswap/sushiswap/blob/master/contracts/uniswapv2/UniswapV2Factory.sol) ([PancakeV2](https://github.com/pancakeswap/pancake-swap-core/blob/master/contracts/PancakeFactory.sol)) Factory | [0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac](https://etherscan.io/address/0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac#code)      | [0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73](https://bscscan.com/address/0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73#code)      | - |
| Network token / USD Chainlink Aggregator | [0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419](https://etherscan.io/address/0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419#code) ([frontend](https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd)) | [0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE](https://bscscan.com/address/0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE#code) ([frontend](https://data.chain.link/bsc/mainnet/crypto-usd/bnb-usd)) | [0xf4766552D15AE4d256Ad41B6cf2933482B0680dc](https://ftmscan.com/address/0xf4766552D15AE4d256Ad41B6cf2933482B0680dc) ([frontend](https://data.chain.link/fantom/mainnet/crypto-usd/ftm-usd)) |
| DUCK      | [0x92E187a03B6CD19CB6AF293ba17F2745Fd2357D5](https://etherscan.io/address/0x92E187a03B6CD19CB6AF293ba17F2745Fd2357D5#code)      | - | - |
| QDUCK      | [0xE85d5FE256F5f5c9E446502aE994fDA12fd6700a](https://etherscan.io/address/0xE85d5FE256F5f5c9E446502aE994fDA12fd6700a#code)      | - | - |
| [FeeDistribution](https://github.com/unitprotocol/fee-distribution)      | [0x3f93dE882dA8150Dc98a3a1F4626E80E3282df46](https://etherscan.io/address/0x3f93dE882dA8150Dc98a3a1F4626E80E3282df46#code)      | - | - |

### Core

| Name          | Mainnet       | Bsc       | Fantom        |
| ------------- |:-------------:|:-------------:|:-------------:|
| Vault | [0xb1cFF81b9305166ff1EFc49A129ad2AfCd7BCf19](https://etherscan.io/address/0xb1cFF81b9305166ff1EFc49A129ad2AfCd7BCf19#code)      | [0xdacfeed000e12c356fb72ab5089e7dd80ff4dd93](https://bscscan.com/address/0xdacfeed000e12c356fb72ab5089e7dd80ff4dd93#code)      | [0xD7A9b0D75e51bfB91c843b23FB2C19aa3B8D958e](https://ftmscan.com/address/0xD7A9b0D75e51bfB91c843b23FB2C19aa3B8D958e) |
| USDP | [0x1456688345527bE1f37E9e627DA0837D6f08C925](https://etherscan.io/address/0x1456688345527bE1f37E9e627DA0837D6f08C925#code)      | [0xdacd011a71f8c9619642bf482f1d4ceb338cffcf](https://bscscan.com/address/0xdacd011a71f8c9619642bf482f1d4ceb338cffcf#code)      | [0x3129aC70c738D398d1D74c87EAB9483FD56D16f8](https://ftmscan.com/address/0x3129aC70c738D398d1D74c87EAB9483FD56D16f8) |
| VaultParameters      | [0xB46F8CF42e504Efe8BEf895f848741daA55e9f1D](https://etherscan.io/address/0xB46F8CF42e504Efe8BEf895f848741daA55e9f1D#code) | [0x56c7CA666d192332F72a5842E72eED5f59F0fb48](https://bscscan.com/address/0x56c7CA666d192332F72a5842E72eED5f59F0fb48#code) | [0xa8F0b5758041158Cf0375b7AdC8AC175ff031B6C](https://ftmscan.com/address/0xa8F0b5758041158Cf0375b7AdC8AC175ff031B6C) |
| VaultManagerParameters      | [0x203153522B9EAef4aE17c6e99851EE7b2F7D312E](https://etherscan.io/address/0x203153522B9EAef4aE17c6e99851EE7b2F7D312E#code)      | [0x99f2B13C28A4183a5d5e0fe02B1B5aeEe85FAF5A](https://bscscan.com/address/0x99f2B13C28A4183a5d5e0fe02B1B5aeEe85FAF5A#code)      | [0x1c7aEA8B6498F0854D1fCE542a27ed6a10D71d2f](https://ftmscan.com/address/0x1c7aEA8B6498F0854D1fCE542a27ed6a10D71d2f) |
| LiquidationAuction02      | [0xaEF1ed4C492BF4C57221bE0706def67813D79955](https://etherscan.io/address/0xaEF1ed4C492BF4C57221bE0706def67813D79955#code)      | [0x852de08f3cD5b92dD8b3B92b321363D04EeEc39E](https://bscscan.com/address/0x852de08f3cD5b92dD8b3B92b321363D04EeEc39E#code)      | [0x1F18FAc6A422cF4a8D18369F017a100C77b49DeF](https://ftmscan.com/address/0x1F18FAc6A422cF4a8D18369F017a100C77b49DeF) |
| CDPManager01      | [0x0e13ab042eC5AB9Fc6F43979406088B9028F66fA](https://etherscan.io/address/0x0e13ab042eC5AB9Fc6F43979406088B9028F66fA#code)      | [0x1337daC01Fc21Fa21D17914f96725f7a7b73868f](https://bscscan.com/address/0x1337daC01Fc21Fa21D17914f96725f7a7b73868f#code)      | [0xdf91608E9779dA9e100FA4448B1b3c0b4430dbc8](https://ftmscan.com/address/0xdf91608E9779dA9e100FA4448B1b3c0b4430dbc8) |
| CDPManager01_Fallback      | [0xaD3617D11f4c1d30603551eA75e9Ace9CB386e15](https://etherscan.io/address/0xaD3617D11f4c1d30603551eA75e9Ace9CB386e15#code)      | - | - |

### Helpers & Registries

| Name          | Mainnet       | Bsc       | Fantom        |
| ------------- |:-------------:|:-------------:|:-------------:|
| OracleRegistry | [0x75fBFe26B21fd3EA008af0C764949f8214150C8f](https://etherscan.io/address/0x75fBFe26B21fd3EA008af0C764949f8214150C8f#code)      | [0xbea721ACe12e881cb44Dbe9361ffEd9141CE547F](https://bscscan.com/address/0xbea721ACe12e881cb44Dbe9361ffEd9141CE547F#code)      | [0x0058aB54d4405D8084e8D71B8AB36B3091b21c7D](https://ftmscan.com/address/0x0058aB54d4405D8084e8D71B8AB36B3091b21c7D) |
| ParametersBatchUpdater | [0x4DD1A6DB148BEcDADAdFC407D23b725eDd3cfB6f](https://etherscan.io/address/0x4DD1A6DB148BEcDADAdFC407D23b725eDd3cfB6f#code)      | [0x3f03b937b986ad10dd171c393562f3fbe03abd9d](https://bscscan.com/address/0x3f03b937b986ad10dd171c393562f3fbe03abd9d#code) | [0xc440Af46DAC68fe74AA4e849Cb798329c44b0908](https://ftmscan.com/address/0xc440Af46DAC68fe74AA4e849Cb798329c44b0908) |
| AssetParametersViewer | [0xd51F509Fb80b4fF4D4Bfb4144eEd877F0F499AF6](https://etherscan.io/address/0xd51F509Fb80b4fF4D4Bfb4144eEd877F0F499AF6#code)      | - | - |
| CollateralRegistry      | [0x3DB39B538Db1123389c77F888a213F1A6dd22EF3](https://etherscan.io/address/0x3DB39B538Db1123389c77F888a213F1A6dd22EF3#code) | [0xA1ad3602697c15113E089C2723c15eBF3038465C](https://bscscan.com/address/0xA1ad3602697c15113E089C2723c15eBF3038465C#code)      | [0x5BEf93a96DCc2cAEC92e8610bb2f5bf5EB4D89f4](https://ftmscan.com/address/0x5BEf93a96DCc2cAEC92e8610bb2f5bf5EB4D89f4) |
| CDPRegistry      | [0x1a5Ff58BC3246Eb233fEA20D32b79B5F01eC650c](https://etherscan.io/address/0x1a5Ff58BC3246Eb233fEA20D32b79B5F01eC650c#code)      | [0xE8372dcef80189c0F88631507f6466b3f60E24A4](https://bscscan.com/address/0xE8372dcef80189c0F88631507f6466b3f60E24A4#code)      | [0x1442bC024a92C2F96c3c1D2E9274bC4d8119d97e](https://ftmscan.com/address/0x1442bC024a92C2F96c3c1D2E9274bC4d8119d97e) |
| ForceTransferAssetStore      | [0xF7633FA353E74Edb211B1d22e23c96aE4d7b24C0](https://etherscan.io/address/0xF7633FA353E74Edb211B1d22e23c96aE4d7b24C0#code)      | [0x7815ed0f9B00E7b34f52543779783023c7621fA1](https://bscscan.com/address/0x7815ed0f9B00E7b34f52543779783023c7621fA1#code)      | [0x828BB32Afa0Ecf70c4f65393664e4a79664d9bD3](https://ftmscan.com/address/0x828BB32Afa0Ecf70c4f65393664e4a79664d9bD3) |
| PancakeV2Twap | - | [0x11b1bd923f4D0669958e16A511567f540Bc21d2e](https://bscscan.com/address/0x11b1bd923f4D0669958e16A511567f540Bc21d2e#code)      | - |

### Oracles

| Name          | Type (alias)       | Mainnet       | Bsc       | Fantom        |
| ------------- |:-------------:|:-------------:|:-------------:|:-------------:|
| ChainlinkedKeydonixOracleMainAsset (Uniswap)      | 1 (3) | [0xBFE2e6eCEdFB9CDf0e9dA98AB116D57DdC82D078](https://etherscan.io/address/0xBFE2e6eCEdFB9CDf0e9dA98AB116D57DdC82D078#code)    | - | - |
| ChainlinkedKeydonixOraclePoolToken      | 2 (4, 8) | [0x72A2e0D0A201B54DcFB668a46BE99494eFF6D2A8](https://etherscan.io/address/0x72A2e0D0A201B54DcFB668a46BE99494eFF6D2A8#code)      | - | - |
| ChainlinkedOracleMainAsset | 5 (3, 7) | [0x54b21C140F5463e1fDa69B934da619eAaa61f1CA](https://etherscan.io/address/0x54b21C140F5463e1fDa69B934da619eAaa61f1CA#code)      | - | [0xEac49454A156AbFF249E2C1A2aEF4E4f192D8Cb9](https://ftmscan.com/address/0xEac49454A156AbFF249E2C1A2aEF4E4f192D8Cb9) |
| BearingAssetOracle      | 9 | [0x190DB945Ae572Ae72E367b549b78C41E211864AB](https://etherscan.io/address/0x190DB945Ae572Ae72E367b549b78C41E211864AB#code)      | - | - |
| ChainlinkedKeep3rV1OracleMainAsset | 7 | - | [0x7562FB711173095Bc2d8100C107e6Da639E0F4B0](https://bscscan.com/address/0x7562FB711173095Bc2d8100C107e6Da639E0F4B0#code)      | - |
| CurveLPOracle      | 10 | [0x0E08d9e1DC22a400EbcA25E9a8f292910fa8fe08](https://etherscan.io/address/0x0E08d9e1DC22a400EbcA25E9a8f292910fa8fe08#code)      | - | - |
| WrappedToUnderlyingOracle      | 11 | [0x220Ea780a484c18fd0Ab252014c58299759a1Fbd](https://etherscan.io/address/0x220Ea780a484c18fd0Ab252014c58299759a1Fbd#code)      | - | [0xf2dA959a37a05685f08CacB2733a19BB008849E1](https://ftmscan.com/address/0xf2dA959a37a05685f08CacB2733a19BB008849E1) |
| OraclePoolToken      | 12 (4, 8) | [0xd88e1F40b6CD9793aa10A6C3ceEA1d01C2a507f9](https://etherscan.io/address/0xd88e1F40b6CD9793aa10A6C3ceEA1d01C2a507f9#code) | - | - |
| ChainlinkedKeydonixOracleMainAsset (Sushiswap)      | 13 (7) | [0x769E35030f5cE160b287Bce0462d46Decf29b6DD](https://etherscan.io/address/0x769E35030f5cE160b287Bce0462d46Decf29b6DD#code)      | - | - |
| CyTokenOracle      | 14 | [0x40B743Ca424E3eC7b97f5AD93d2263Ae01DAE1D8](https://etherscan.io/address/0x40B743Ca424E3eC7b97f5AD93d2263Ae01DAE1D8#code)      | - | - |
| YvTokenOracle      | 15 | [0x759EB07A8258BcF5590E9303763803DcF264652d](https://etherscan.io/address/0x759EB07A8258BcF5590E9303763803DcF264652d#code)      | - | - |
| [UniswapV3Oracle](https://github.com/unitprotocol/uniswap-v3-oracle)      | 16 | [0xd31817a1E1578C4BECE02FbFb235d76f5716f18f](https://etherscan.io/address/0xd31817a1E1578C4BECE02FbFb235d76f5716f18f#code)  | - | - |
