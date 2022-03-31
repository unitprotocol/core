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
 * @dev base class for swappers, makes common checks
 * @dev internal _swapUsdpToAsset and _swapAssetToUsdp must be overridden instead of external swapUsdpToAsset and swapAssetToUsdp
 */
abstract contract AbstractSwapper is ISwapper, ReentrancyGuard, Auth2 {
    using TransferHelper for address;
    using SafeMath for uint;

    IERC20 public immutable USDP;

    constructor(address _vaultParameters, address _usdp) Auth2(_vaultParameters) {
        require(_usdp != address(0), "Unit Protocol Swappers: ZERO_ADDRESS");

        USDP = IERC20(_usdp);
    }

    /**
     * @dev usdp already transferred to swapper
     */
    function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        internal virtual returns (uint swappedAssetAmount);

    /**
     * @dev asset already transferred to swapper
     */
    function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        internal virtual returns (uint swappedUsdpAmount);

    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        external override returns (uint swappedAssetAmount) // nonReentrant in swapUsdpToAssetWithDirectSending
    {
        // get USDP from user
        address(USDP).safeTransferFrom(_user, address(this), _usdpAmount);

        return swapUsdpToAssetWithDirectSending(_user, _asset, _usdpAmount, _minAssetAmount);
    }

    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        external override returns (uint swappedUsdpAmount) // nonReentrant in swapAssetToUsdpWithDirectSending
    {
        // get asset from user
        _asset.safeTransferFrom(_user, address(this), _assetAmount);

        return swapAssetToUsdpWithDirectSending(_user, _asset, _assetAmount, _minUsdpAmount);
    }

    function swapUsdpToAssetWithDirectSending(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        public override nonReentrant returns (uint swappedAssetAmount)
    {
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Swappers: AUTH_FAILED");

        swappedAssetAmount = _swapUsdpToAsset(_user, _asset, _usdpAmount, _minAssetAmount);

        require(swappedAssetAmount >= _minAssetAmount, "Unit Protocol Swapper: SWAPPED_AMOUNT_LESS_THAN_EXPECTED_MINIMUM");
    }

    function swapAssetToUsdpWithDirectSending(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        public override nonReentrant returns (uint swappedUsdpAmount)
    {
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Swappers: AUTH_FAILED");

        swappedUsdpAmount = _swapAssetToUsdp(_user, _asset, _assetAmount, _minUsdpAmount);

        require(swappedUsdpAmount >= _minUsdpAmount, "Unit Protocol Swappers: SWAPPED_AMOUNT_LESS_THAN_EXPECTED_MINIMUM");
    }
}
