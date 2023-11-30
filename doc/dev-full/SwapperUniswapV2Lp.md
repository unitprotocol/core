# Solidity API

## SwapperUniswapV2Lp

_swap usdp/any uniswapv2 lp_

### WETH

```solidity
address WETH
```

### wethSwapper

```solidity
contract ISwapper wethSwapper
```

### constructor

```solidity
constructor(address _vaultParameters, address _weth, address _usdp, address _wethSwapper) public
```

### predictAssetOut

```solidity
function predictAssetOut(address _asset, uint256 _usdpAmountIn) external view returns (uint256 predictedAssetAmount)
```

Predict asset amount after usdp swap

### predictUsdpOut

```solidity
function predictUsdpOut(address _asset, uint256 _assetAmountIn) external view returns (uint256 predictedUsdpAmount)
```

Predict USDP amount after asset swap

### _swapUsdpToAsset

```solidity
function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256) internal returns (uint256 swappedAssetAmount)
```

### _swapAssetToUsdp

```solidity
function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256) internal returns (uint256 swappedUsdpAmount)
```

### _swapPairTokens

```solidity
function _swapPairTokens(contract IUniswapV2PairFull _pair, address _token, uint256 _tokenId, uint256 _amount, address _to) internal returns (uint256 tokenAmount)
```

