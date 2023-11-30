// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/swappers/ISwapper.sol";
import "../helpers/ReentrancyGuard.sol";
import '../helpers/TransferHelper.sol';
import "../helpers/SafeMath.sol";
import "../Auth2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AbstractSwapper
 * @dev Abstract contract for creating swapper contracts that handle asset swaps with USDP.
 * @dev Child classes must implement internal _swapUsdpToAsset and _swapAssetToUsdp functions.
 */
abstract contract AbstractSwapper is ISwapper, ReentrancyGuard, Auth2 {
    using TransferHelper for address;
    using SafeMath for uint;

    IERC20 public immutable USDP;

    /**
     * @dev Sets the USDP token address and initializes the Auth2 contract.
     * @param _vaultParameters The address of the vault parameters contract.
     * @param _usdp The address of the USDP token contract.
     */
    constructor(address _vaultParameters, address _usdp) Auth2(_vaultParameters) {
        require(_usdp != address(0), "Unit Protocol Swappers: ZERO_ADDRESS");

        USDP = IERC20(_usdp);
    }

    /**
     * @dev Internal function to swap USDP to another asset.
     * @param _user The address of the user initiating the swap.
     * @param _asset The address of the asset to swap to.
     * @param _usdpAmount The amount of USDP to swap.
     * @param _minAssetAmount The minimum amount of the asset expected to receive.
     * @return swappedAssetAmount The amount of asset tokens swapped.
     */
    function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        internal virtual returns (uint swappedAssetAmount);

    /**
     * @dev Internal function to swap an asset to USDP.
     * @param _user The address of the user initiating the swap.
     * @param _asset The address of the asset to swap from.
     * @param _assetAmount The amount of the asset to swap.
     * @param _minUsdpAmount The minimum amount of USDP expected to receive.
     * @return swappedUsdpAmount The amount of USDP tokens swapped.
     */
    function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        internal virtual returns (uint swappedUsdpAmount);

    /**
     * @dev Swaps USDP to another asset with a direct transfer.
     * @param _user The address of the user initiating the swap.
     * @param _asset The address of the asset to swap to.
     * @param _usdpAmount The amount of USDP to swap.
     * @param _minAssetAmount The minimum amount of the asset expected to receive.
     * @return swappedAssetAmount The amount of asset tokens swapped.
     */
    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        external override returns (uint swappedAssetAmount) // nonReentrant in swapUsdpToAssetWithDirectSending
    {
        // get USDP from user
        address(USDP).safeTransferFrom(_user, address(this), _usdpAmount);

        return swapUsdpToAssetWithDirectSending(_user, _asset, _usdpAmount, _minAssetAmount);
    }

    /**
     * @dev Swaps an asset to USDP and sends the USDP to the user.
     * @param _user Address of the user initiating the swap.
     * @param _asset Address of the asset to swap from.
     * @param _assetAmount Amount of the asset to swap.
     * @param _minUsdpAmount Minimum amount of USDP expected to receive.
     * @return swappedUsdpAmount Amount of USDP tokens received from the swap.
     */
    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        external override returns (uint swappedUsdpAmount) // nonReentrant in swapAssetToUsdpWithDirectSending
    {
        // get asset from user
        _asset.safeTransferFrom(_user, address(this), _assetAmount);

        return swapAssetToUsdpWithDirectSending(_user, _asset, _assetAmount, _minUsdpAmount);
    }


    /**
     * @dev Swaps USDP to another asset with a direct transfer.
     * @param _user The address of the user initiating the swap.
     * @param _asset The address of the asset to swap to.
     * @param _usdpAmount The amount of USDP to swap.
     * @param _minAssetAmount The minimum amount of the asset expected to receive.
     * @return swappedAssetAmount The amount of asset tokens swapped.
     */
    function swapUsdpToAssetWithDirectSending(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        public override nonReentrant returns (uint swappedAssetAmount)
    {
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Swappers: AUTH_FAILED");

        swappedAssetAmount = _swapUsdpToAsset(_user, _asset, _usdpAmount, _minAssetAmount);

        require(swappedAssetAmount >= _minAssetAmount, "Unit Protocol Swapper: SWAPPED_AMOUNT_LESS_THAN_EXPECTED_MINIMUM");
    }

    /**
     * @dev Swaps an asset to USDP with a direct transfer.
     * @param _user The address of the user initiating the swap.
     * @param _asset The address of the asset to swap from.
     * @param _assetAmount The amount of the asset to swap.
     * @param _minUsdpAmount The minimum amount of USDP expected to receive.
     * @return swappedUsdpAmount The amount of USDP tokens swapped.
     */
    function swapAssetToUsdpWithDirectSending(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        public override nonReentrant returns (uint swappedUsdpAmount)
    {
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Swappers: AUTH_FAILED");

        swappedUsdpAmount = _swapAssetToUsdp(_user, _asset, _assetAmount, _minUsdpAmount);

        require(swappedUsdpAmount >= _minUsdpAmount, "Unit Protocol Swappers: SWAPPED_AMOUNT_LESS_THAN_EXPECTED_MINIMUM");
    }

    /**
     * @dev External function to swap USDP to another asset. USDP is transferred from the user.
     * @param _user The address of the user initiating the swap.
     * @param _asset The address of the asset to swap to.
     * @param _usdpAmount The amount of USDP to swap.
     * @param _minAssetAmount The minimum amount of the asset expected to receive.
     * @return swappedAssetAmount The amount of asset tokens swapped.
     */
    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        external override returns (uint swappedAssetAmount)
    {
        address(USDP).safeTransferFrom(_user, address(this), _usdpAmount);
        return swapUsdpToAssetWithDirectSending(_user, _asset, _usdpAmount, _minAssetAmount);
    }

    /**
     * @dev External function to swap an asset to USDP. The asset is transferred from the user.
     * @param _user The address of the user initiating the swap.
     * @param _asset The address of the asset to swap from.
     * @param _assetAmount The amount of the asset to swap.
     * @param _minUsdpAmount The minimum amount of USDP expected to receive.
     * @return swappedUsdpAmount The amount of USDP tokens swapped.
     */
    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        external override returns (uint swappedUsdpAmount)
    {
        _asset.safeTransferFrom(_user, address(this), _assetAmount);
        return swapAssetToUsdpWithDirectSending(_user, _asset, _assetAmount, _minUsdpAmount);
    }
}