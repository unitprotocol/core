// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;


import "../interfaces/swappers/ISwapper.sol";
import "./AbstractSwapper.sol";
import "./helpers/CurveHelper.sol";
import "../interfaces/curve/ICurvePoolMeta.sol";
import "../interfaces/curve/ICurvePoolCrypto.sol";
import "../helpers/SafeMath.sol";
import "../helpers/IUniswapV2PairFull.sol";
import '../helpers/TransferHelper.sol';
import "../helpers/ReentrancyGuard.sol";
import "../Auth2.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @dev swap usdp/weth
 */
contract SwapperWethViaCurve is AbstractSwapper {
    using SafeMath for uint;
    using CurveHelper for ICurvePoolMeta;
    using CurveHelper for ICurvePoolCrypto;
    using TransferHelper for address;

    IERC20 public immutable WETH;
    IERC20 public immutable USDT;

    ICurvePoolMeta public immutable USDP_3CRV_POOL;
    int128 public immutable USDP_3CRV_POOL_USDP;
    int128 public immutable USDP_3CRV_POOL_USDT;

    ICurvePoolCrypto public immutable TRICRYPTO2_POOL;
    uint256 public immutable TRICRYPTO2_USDT;
    uint256 public immutable TRICRYPTO2_WETH;


    constructor(
        address _vaultParameters, address _weth,  address _usdp, address _usdt,
        address _usdp3crvPool, address _tricrypto2Pool
    ) AbstractSwapper(_vaultParameters, _usdp) {
        require(
            _weth != address(0)
            && _usdt != address(0)
            && _usdp3crvPool != address(0)
            && _tricrypto2Pool != address(0)
            , "Unit Protocol Swappers: ZERO_ADDRESS"
        );

        WETH = IERC20(_weth);
        USDT = IERC20(_usdt);

        USDP_3CRV_POOL = ICurvePoolMeta(_usdp3crvPool);
        USDP_3CRV_POOL_USDP = ICurvePoolMeta(_usdp3crvPool).getCoinIndexInMetaPool(_usdp);
        USDP_3CRV_POOL_USDT = ICurvePoolMeta(_usdp3crvPool).getCoinIndexInMetaPool(_usdt);

        TRICRYPTO2_POOL = ICurvePoolCrypto(_tricrypto2Pool);
        TRICRYPTO2_USDT = uint(ICurvePoolCrypto(_tricrypto2Pool).getCoinIndexInPool(_usdt));
        TRICRYPTO2_WETH = uint(ICurvePoolCrypto(_tricrypto2Pool).getCoinIndexInPool(_weth));

        // for usdp to weth
        _usdp.safeApprove(_usdp3crvPool, type(uint256).max);
        _usdt.safeApprove(_tricrypto2Pool, type(uint256).max);

        // for weth to usdp
        _weth.safeApprove(_tricrypto2Pool, type(uint256).max);
        _usdt.safeApprove(_usdp3crvPool, type(uint256).max);
    }

    function predictAssetOut(address _asset, uint256 _usdpAmountIn) external view override returns (uint predictedAssetAmount) {
        require(_asset == address(WETH), "Unit Protocol Swappers: UNSUPPORTED_ASSET");

        // USDP -> USDT
        uint usdtAmount = USDP_3CRV_POOL.get_dy_underlying(USDP_3CRV_POOL_USDP, USDP_3CRV_POOL_USDT, _usdpAmountIn);

        // USDT -> WETH
        predictedAssetAmount = TRICRYPTO2_POOL.get_dy(TRICRYPTO2_USDT, TRICRYPTO2_WETH, usdtAmount);
    }

    /**
     * @dev calculates with some small (~0.005%) error bcs of approximate calculations of fee in get_dy_underlying
     */
    function predictUsdpOut(address _asset, uint256 _assetAmountIn) external view override returns (uint predictedUsdpAmount) {
        require(_asset == address(WETH), "Unit Protocol Swappers: UNSUPPORTED_ASSET");

        // WETH -> USDT
        uint usdtAmount = TRICRYPTO2_POOL.get_dy(TRICRYPTO2_WETH, TRICRYPTO2_USDT, _assetAmountIn);

        // USDT -> USDP
        predictedUsdpAmount = USDP_3CRV_POOL.get_dy_underlying(USDP_3CRV_POOL_USDT, USDP_3CRV_POOL_USDP, usdtAmount);
    }

    function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 /** _minAssetAmount */)
        internal override returns (uint swappedAssetAmount)
    {
        require(_asset == address(WETH), "Unit Protocol Swappers: UNSUPPORTED_ASSET");

        // USDP -> USDT
        uint usdtAmount = USDP_3CRV_POOL.exchange_underlying(USDP_3CRV_POOL_USDP, USDP_3CRV_POOL_USDT, _usdpAmount, 0);

        // USDT -> WETH
        TRICRYPTO2_POOL.exchange(TRICRYPTO2_USDT, TRICRYPTO2_WETH, usdtAmount, 0);
        swappedAssetAmount = WETH.balanceOf(address(this));

        // WETH -> user
        address(WETH).safeTransfer(_user, swappedAssetAmount);
    }

    function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 /** _minUsdpAmount */)
        internal override returns (uint swappedUsdpAmount)
    {
        require(_asset == address(WETH), "Unit Protocol Swappers: UNSUPPORTED_ASSET");

        // WETH -> USDT
        TRICRYPTO2_POOL.exchange(TRICRYPTO2_WETH, TRICRYPTO2_USDT, _assetAmount, 0);
        uint usdtAmount = USDT.balanceOf(address(this));

        // USDT -> USDP
        swappedUsdpAmount = USDP_3CRV_POOL.exchange_underlying(USDP_3CRV_POOL_USDT, USDP_3CRV_POOL_USDP, usdtAmount, 0);

        // USDP -> user
        address(USDP).safeTransfer(_user, swappedUsdpAmount);
    }
}
