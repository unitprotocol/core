# Solidity API

## SwapperWethViaCurve

_swap usdp/weth_

### WETH

```solidity
contract IERC20 WETH
```

### USDT

```solidity
contract IERC20 USDT
```

### USDP_3CRV_POOL

```solidity
contract ICurvePoolMeta USDP_3CRV_POOL
```

### USDP_3CRV_POOL_USDP

```solidity
int128 USDP_3CRV_POOL_USDP
```

### USDP_3CRV_POOL_USDT

```solidity
int128 USDP_3CRV_POOL_USDT
```

### TRICRYPTO2_POOL

```solidity
contract ICurvePoolCrypto TRICRYPTO2_POOL
```

### TRICRYPTO2_USDT

```solidity
uint256 TRICRYPTO2_USDT
```

### TRICRYPTO2_WETH

```solidity
uint256 TRICRYPTO2_WETH
```

### constructor

```solidity
constructor(address _vaultParameters, address _weth, address _usdp, address _usdt, address _usdp3crvPool, address _tricrypto2Pool) public
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

_calculates with some small (~0.005%) error bcs of approximate calculations of fee in get_dy_underlying_

### _swapUsdpToAsset

```solidity
function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256) internal returns (uint256 swappedAssetAmount)
```

### _swapAssetToUsdp

```solidity
function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256) internal returns (uint256 swappedUsdpAmount)
```

