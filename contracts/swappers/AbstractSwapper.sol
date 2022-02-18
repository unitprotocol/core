// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;


import "../interfaces/swappers/ISwapper.sol";
import "../helpers/ReentrancyGuard.sol";
import "../Auth2.sol";

/**
 * @dev base class for swappers, makes common checks
 * @dev internal _swapUsdpToAsset and _swapAssetToUsdp must be overridden instead of external swapUsdpToAsset and swapAssetToUsdp
 */
abstract contract AbstractSwapper is ISwapper, ReentrancyGuard, Auth2 {
    constructor(address _vaultParameters) Auth2(_vaultParameters) {}

    function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        internal virtual returns (uint swappedAssetAmount);

    function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        internal virtual returns (uint swappedUsdpAmount);

    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        external override nonReentrant returns (uint swappedAssetAmount)
    {
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Swappers: AUTH_FAILED");

        swappedAssetAmount = _swapUsdpToAsset(_user, _asset, _usdpAmount, _minAssetAmount);

        require(swappedAssetAmount >= _minAssetAmount, "Unit Protocol Swapper: INVALID_SWAP");
        return swappedAssetAmount;
    }

    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        external override nonReentrant returns (uint swappedUsdpAmount)
    {
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Swappers: AUTH_FAILED");

        swappedUsdpAmount = _swapAssetToUsdp(_user, _asset, _assetAmount, _minUsdpAmount);

        require(swappedUsdpAmount >= _minUsdpAmount, "Unit Protocol Swappers: INVALID_SWAP");
        return swappedUsdpAmount;
    }
}
