# Solidity API

## UniswapV2Helper

_several methods for calculations different uniswap v2 params. Part of them extracted for uniswap contracts
for original licenses see attached links_

### quote

```solidity
function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB)
```

given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
see https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol

### getAmountOut

```solidity
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountOut)
```

given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
see https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol

### getLPAmountAddedDuringFeeMint

```solidity
function getLPAmountAddedDuringFeeMint(contract IUniswapV2PairFull pair, uint256 _reserve0, uint256 _reserve1) internal view returns (uint256)
```

see pair._mintFee in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol

### calculateLpAmountAfterDepositTokens

```solidity
function calculateLpAmountAfterDepositTokens(contract IUniswapV2PairFull _pair, uint256 _amount0, uint256 _amount1) internal view returns (uint256)
```

see pair.mint in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol

### calculateLpAmountAfterDepositTokens

```solidity
function calculateLpAmountAfterDepositTokens(contract IUniswapV2PairFull _pair, uint256 _amount0, uint256 _amount1, uint256 _reserve0, uint256 _reserve1) internal view returns (uint256)
```

### calculateTokensAmountAfterWithdrawLp

```solidity
function calculateTokensAmountAfterWithdrawLp(contract IUniswapV2PairFull pair, uint256 lpAmount) internal view returns (uint256 amount0, uint256 amount1)
```

see pair.burn in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol

### getTokenInfo

```solidity
function getTokenInfo(contract IUniswapV2PairFull pair, address _token) internal view returns (uint256 tokenId, uint256 secondTokenId, address secondToken)
```

### calcAmountOutByTokenId

```solidity
function calcAmountOutByTokenId(contract IUniswapV2PairFull _pair, uint256 _tokenId, uint256 _amount) internal view returns (uint256)
```

### calcAmountOutByTokenId

```solidity
function calcAmountOutByTokenId(contract IUniswapV2PairFull, uint256 _tokenId, uint256 _amount, uint256 reserve0, uint256 reserve1) internal pure returns (uint256)
```

### calcWethToSwapBeforeMint

```solidity
function calcWethToSwapBeforeMint(contract IUniswapV2PairFull _pair, uint256 _wethAmount, uint256 _pairWethId) internal view returns (uint256 wethToSwap)
```

_In case we want to get pair LP tokens but we have weth only
- First we swap `wethToSwap` tokens
- then we deposit `_wethAmount-wethToSwap` and `exchangedTokenAmount` to pair_

