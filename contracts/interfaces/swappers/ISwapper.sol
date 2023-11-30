// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title ISwapper
 * @dev Interface for swapping assets with USDP (USD Pegged) token.
 */
interface ISwapper {

    /**
     * @notice Predicts the amount of asset that will be received after swapping a given amount of USDP.
     * @param _asset The address of the asset to swap to.
     * @param _usdpAmountIn The amount of USDP to be swapped.
     * @return predictedAssetAmount The predicted amount of asset that will be received.
     */
    function predictAssetOut(address _asset, uint256 _usdpAmountIn) external view returns (uint predictedAssetAmount);

    /**
     * @notice Predicts the amount of USDP that will be received after swapping a given amount of asset.
     * @param _asset The address of the asset to swap from.
     * @param _assetAmountIn The amount of the asset to be swapped.
     * @return predictedUsdpAmount The predicted amount of USDP that will be received.
     */
    function predictUsdpOut(address _asset, uint256 _assetAmountIn) external view returns (uint predictedUsdpAmount);

    /**
     * @notice Swaps USDP to a specified asset for a user.
     * @dev The user must approve the USDP amount to the swapper contract before calling this function.
     *      The asset is sent to the user after the swap.
     * @param _user The address of the user to receive the swapped asset.
     * @param _asset The address of the asset to swap to.
     * @param _usdpAmount The amount of USDP to swap.
     * @param _minAssetAmount The minimum amount of asset expected to receive.
     * @return swappedAssetAmount The actual amount of asset received from the swap.
     */
    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external returns (uint swappedAssetAmount);

    /**
     * @notice Swaps an asset to USDP for a user.
     * @dev The user must approve the asset amount to the swapper contract before calling this function.
     *      The USDP is sent to the user after the swap.
     * @param _user The address of the user to receive the swapped USDP.
     * @param _asset The address of the asset to swap from.
     * @param _assetAmount The amount of the asset to swap.
     * @param _minUsdpAmount The minimum amount of USDP expected to receive.
     * @return swappedUsdpAmount The actual amount of USDP received from the swap.
     */
    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) external returns (uint swappedUsdpAmount);

    /**
     * @notice Swaps USDP to a specified asset for a user with direct sending of tokens to save gas.
     * @dev This function is intended for use in contracts only, to save gas by sending tokens directly to the contract.
     *      The asset is sent to the user after the swap.
     *      DO NOT SEND tokens to the contract manually when using this function.
     * @param _user The address of the user to receive the swapped asset.
     * @param _asset The address of the asset to swap to.
     * @param _usdpAmount The amount of USDP to swap.
     * @param _minAssetAmount The minimum amount of asset expected to receive.
     * @return swappedAssetAmount The actual amount of asset received from the swap.
     */
    function swapUsdpToAssetWithDirectSending(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external returns (uint swappedAssetAmount);

    /**
     * @notice Swaps an asset to USDP for a user with direct sending of tokens to save gas.
     * @dev This function is intended for use in contracts only, to save gas by sending tokens directly to the contract.
     *      The USDP is sent to the user after the swap.
     *      DO NOT SEND tokens to the contract manually when using this function.
     * @param _user The address of the user to receive the swapped USDP.
     * @param _asset The address of the asset to swap from.
     * @param _assetAmount The amount of the asset to swap.
     * @param _minUsdpAmount The minimum amount of USDP expected to receive.
     * @return swappedUsdpAmount The actual amount of USDP received from the swap.
     */
    function swapAssetToUsdpWithDirectSending(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) external returns (uint swappedUsdpAmount);
}