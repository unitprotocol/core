// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/swappers/ISwapper.sol";
import "./IAssetTestsMint.sol";
import "../helpers/TransferHelper.sol";

/**
 * @title SwapperMock
 * @dev Used in tests
 **/
contract SwapperMock is ISwapper {

    uint public assetToUsdpRate = 1;
    address public immutable USDP;

    constructor(address _usdp) {
        USDP = _usdp;
    }

    function tests_setAssetToUsdpRate(uint _rate) public {
        assetToUsdpRate = _rate;
    }

    function predictAssetOut(address /* _asset */, uint256 _usdpAmountIn) external view override returns (uint predictedAssetAmount) {
        return _usdpAmountIn / assetToUsdpRate;
    }

    function predictUsdpOut(address /* _asset */, uint256 _assetAmountIn) external view override returns (uint predictedUsdpAmount) {
        return _assetAmountIn * assetToUsdpRate;
    }

    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external override returns (uint swappedAssetAmount) {
        require(_minAssetAmount == _usdpAmount / assetToUsdpRate); // in _minAssetAmount we must send result of prediction. In tests the same
        TransferHelper.safeTransferFrom(USDP, _user, address(this), _usdpAmount);
        IAssetTestsMint(_asset).tests_mint(_user, _minAssetAmount);
        return _minAssetAmount;
    }

    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) external override returns (uint swappedUsdpAmount) {
        require(_minUsdpAmount == _assetAmount * assetToUsdpRate); // in _minAssetAmount we must send result of prediction. In tests the same
        TransferHelper.safeTransferFrom(_asset, _user, address(this), _assetAmount);
        IAssetTestsMint(USDP).tests_mint(_user, _minUsdpAmount);
        return _minUsdpAmount;
    }

    function swapUsdpToAssetWithDirectSending(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external override returns (uint swappedAssetAmount) {
        require(_minAssetAmount == _usdpAmount / assetToUsdpRate); // in _minAssetAmount we must send result of prediction. In tests the same
        IAssetTestsMint(_asset).tests_mint(_user, _minAssetAmount);
        return _minAssetAmount;
    }

    function swapAssetToUsdpWithDirectSending(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) external override returns (uint swappedUsdpAmount) {
        require(_minUsdpAmount == _assetAmount * assetToUsdpRate); // in _minAssetAmount we must send result of prediction. In tests the same
        IAssetTestsMint(USDP).tests_mint(_user, _minUsdpAmount);
        return _minUsdpAmount;
    }
}
