# Solidity API

## AbstractSwapper

_base class for swappers, makes common checks
internal _swapUsdpToAsset and _swapAssetToUsdp must be overridden instead of external swapUsdpToAsset and swapAssetToUsdp_

### USDP

```solidity
contract IERC20 USDP
```

### constructor

```solidity
constructor(address _vaultParameters, address _usdp) internal
```

### _swapUsdpToAsset

```solidity
function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) internal virtual returns (uint256 swappedAssetAmount)
```

_usdp already transferred to swapper_

### _swapAssetToUsdp

```solidity
function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) internal virtual returns (uint256 swappedUsdpAmount)
```

_asset already transferred to swapper_

### swapUsdpToAsset

```solidity
function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external returns (uint256 swappedAssetAmount)
```

usdp must be approved to swapper

_asset must be sent to user after swap_

### swapAssetToUsdp

```solidity
function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) external returns (uint256 swappedUsdpAmount)
```

asset must be approved to swapper

_usdp must be sent to user after swap_

### swapUsdpToAssetWithDirectSending

```solidity
function swapUsdpToAssetWithDirectSending(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) public returns (uint256 swappedAssetAmount)
```

DO NOT SEND tokens to contract manually. For usage in contracts only.

_for gas saving with usage in contracts tokens must be send directly to contract instead
asset must be sent to user after swap_

### swapAssetToUsdpWithDirectSending

```solidity
function swapAssetToUsdpWithDirectSending(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) public returns (uint256 swappedUsdpAmount)
```

DO NOT SEND tokens to contract manually. For usage in contracts only.

_for gas saving with usage in contracts tokens must be send directly to contract instead
usdp must be sent to user after swap_

