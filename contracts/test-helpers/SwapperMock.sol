// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/swappers/ISwapper.sol";
import "./IAssetTestsMint.sol";
import "../helpers/TransferHelper.sol";

/* 
 * @title SwapperMock
 * @dev Mock implementation of the ISwapper interface for testing purposes.
 */
contract SwapperMock is ISwapper {

    /* @notice The conversion rate from asset to USDP. */
    uint public assetToUsdpRate = 1;

    /* @notice Address of the USDP token. */
    address public immutable USDP;

    /* 
     * @dev Sets the address of the USDP token upon contract creation.
     * @param _usdp The address of the USDP token.
     */
    constructor(address _usdp) {
        USDP = _usdp;
    }

    /* 
     * @dev Sets the conversion rate from asset to USDP for testing purposes.
     * @param _rate The new conversion rate.
     */
    function tests_setAssetToUsdpRate(uint _rate) public {
        assetToUsdpRate = _rate;
    }

    /* 
     * @dev Predicts the amount of asset that can be obtained for a given USDP amount.
     * @param _usdpAmountIn The amount of USDP to be swapped.
     * @return predictedAssetAmount The predicted amount of asset that will be received.
     */
    function predictAssetOut(address /* _asset */, uint256 _usdpAmountIn) external view override returns (uint predictedAssetAmount) {
        return _usdpAmountIn / assetToUsdpRate;
    }

    /* 
     * @dev Predicts the amount of USDP that can be obtained for a given asset amount.
     * @param _assetAmountIn The amount of asset to be swapped.
     * @return predictedUsdpAmount The predicted amount of USDP that will be received.
     */
    function predictUsdpOut(address /* _asset */, uint256 _assetAmountIn) external view override returns (uint predictedUsdpAmount) {
        return _assetAmountIn * assetToUsdpRate;
    }

    /* 
     * @dev Swaps USDP for asset and sends the asset to the specified user.
     * @param _user The address of the user to receive the asset.
     * @param _asset The address of the asset to be swapped.
     * @param _usdpAmount The amount of USDP to be swapped.
     * @param _minAssetAmount The minimum amount of asset expected to be received.
     * @return swappedAssetAmount The amount of asset actually swapped.
     * @notice The function requires the minimum asset amount to be equal to the result of the USDP amount divided by the conversion rate.
     */
    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external override returns (uint swappedAssetAmount) {
        require(_minAssetAmount == _usdpAmount / assetToUsdpRate); // in _minAssetAmount we must send result of prediction. In tests the same
        TransferHelper.safeTransferFrom(USDP, _user, address(this), _usdpAmount);
        IAssetTestsMint(_asset).tests_mint(_user, _minAssetAmount);
        return _minAssetAmount;
    }

    /* 
     * @dev Swaps asset for USDP and sends the USDP to the specified user.
     * @param _user The address of the user to receive the USDP.
     * @param _asset The address of the asset to be swapped.
     * @param _assetAmount The amount of asset to be swapped.
     * @param _minUsdpAmount The minimum amount of USDP expected to be received.
     * @return swappedUsdpAmount The amount of USDP actually swapped.
     * @notice The function requires the minimum USDP amount to be equal to the result of the asset amount multiplied by the conversion rate.
     */
    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) external override returns (uint swappedUsdpAmount) {
        require(_minUsdpAmount == _assetAmount * assetToUsdpRate); // in _minAssetAmount we must send result of prediction. In tests the same
        TransferHelper.safeTransferFrom(_asset, _user, address(this), _assetAmount);
        IAssetTestsMint(USDP).tests_mint(_user, _minUsdpAmount);
        return _minUsdpAmount;
    }

    /* 
     * @dev Swaps USDP for asset and directly sends the asset to the specified user without transferring USDP to the contract first.
     * @param _user The address of the user to receive the asset.
     * @param _asset The address of the asset to be swapped.
     * @param _usdpAmount The amount of USDP to be swapped.
     * @param _minAssetAmount The minimum amount of asset expected to be received.
     * @return swappedAssetAmount The amount of asset actually swapped.
     * @notice The function requires the minimum asset amount to be equal to the result of the USDP amount divided by the conversion rate.
     */
    function swapUsdpToAssetWithDirectSending(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external override returns (uint swappedAssetAmount) {
        require(_minAssetAmount == _usdpAmount / assetToUsdpRate); // in _minAssetAmount we must send result of prediction. In tests the same
        IAssetTestsMint(_asset).tests_mint(_user, _minAssetAmount);
        return _minAssetAmount;
    }

    /* 
     * @dev Swaps asset for USDP and directly sends the USDP to the specified user without transferring the asset to the contract first.
     * @param _user The address of the user to receive the USDP.
     * @param _assetAmount The amount of asset to be swapped.
     * @param _minUsdpAmount The minimum amount of USDP expected to be received.
     * @return swappedUsdpAmount The amount of USDP actually swapped.
     * @notice The function requires the minimum USDP amount to be equal to the result of the asset amount multiplied by the conversion rate.
     */
    function swapAssetToUsdpWithDirectSending(address _user, address /* _asset */, uint256 _assetAmount, uint256 _minUsdpAmount) external override returns (uint swappedUsdpAmount) {
        require(_minUsdpAmount == _assetAmount * assetToUsdpRate); // in _minAssetAmount we must send result of prediction. In tests the same
        IAssetTestsMint(USDP).tests_mint(_user, _minUsdpAmount);
        return _minUsdpAmount;
    }
}