// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;


import "../interfaces/swappers/ISwapper.sol";
import "../interfaces/ICurveWith3crvPool.sol";
import "../interfaces/ICurveTricrypto2Pool.sol";
import "../helpers/SafeMath.sol";
import "../helpers/IUniswapV2PairFull.sol";
import '../helpers/TransferHelper.sol';
import "../helpers/ReentrancyGuard.sol";
import "../Auth2.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @dev swap usdp/weth
 */
contract SwapperWethViaCurve is ISwapper, ReentrancyGuard, Auth2 {
    using SafeMath for uint;

    IERC20 public immutable WETH;
    IERC20 public immutable USDP;
    IERC20 public immutable USDT;

    ICurveWith3crvPool public immutable USDP_3CRV_POOL;
    int128 public immutable USDP_3CRV_POOL_USDP;
    int128 public immutable USDP_3CRV_POOL_USDT;

    ICurveTricrypto2Pool public immutable TRICRYPTO2_POOL;
    uint256 public immutable TRICRYPTO2_USDT;
    uint256 public immutable TRICRYPTO2_WETH;


    constructor(
        address _vaultParameters, address _weth,  address _usdp, address _usdt,
        address _usdp3crvPool, int128 _usdp3crvPoolUsdpIndex, int128 _usdp3crvPoolUsdtIndex,
        address _tricrypto2Pool, uint256 _tricrypto2PoolUsdtIndex, uint256 _tricrypto2PoolWethIndex
    ) Auth2(_vaultParameters) {
        require(
            _weth != address(0)
            && _usdp != address(0)
            && _usdt != address(0)
            && _usdp3crvPool != address(0)
            && _tricrypto2Pool != address(0)
            , "Unit Protocol Swappers: ZERO_ADDRESS"
        );
        require(_usdp3crvPoolUsdpIndex != _usdp3crvPoolUsdtIndex && _tricrypto2PoolUsdtIndex != _tricrypto2PoolWethIndex, "Unit Protocol Swappers: INVALID_TOKENS_INDEXES");

        WETH = IERC20(_weth);
        USDP = IERC20(_usdp);
        USDT = IERC20(_usdt);

        USDP_3CRV_POOL = ICurveWith3crvPool(_usdp3crvPool);
        USDP_3CRV_POOL_USDP = _usdp3crvPoolUsdpIndex;
        USDP_3CRV_POOL_USDT = _usdp3crvPoolUsdtIndex;

        TRICRYPTO2_POOL = ICurveTricrypto2Pool(_tricrypto2Pool);
        TRICRYPTO2_USDT = _tricrypto2PoolUsdtIndex;
        TRICRYPTO2_WETH = _tricrypto2PoolWethIndex;

        // for usdp to weth
        TransferHelper.safeApprove(_usdp, _usdp3crvPool, type(uint256).max);
        TransferHelper.safeApprove(_usdt, _tricrypto2Pool, type(uint256).max);

        // for weth to usdp
        TransferHelper.safeApprove(_weth, _tricrypto2Pool, type(uint256).max);
        TransferHelper.safeApprove(_usdt, _usdp3crvPool, type(uint256).max);
    }

    function predictAssetOut(address _asset, uint256 _usdpAmountIn) external view override returns (uint predictedAssetAmount) {
        require(_asset == address(WETH), "Unit Protocol Swappers: UNSUPPORTED_ASSET");

        // USDP -> USDT
        uint usdtAmount = USDP_3CRV_POOL.get_dy_underlying(USDP_3CRV_POOL_USDP, USDP_3CRV_POOL_USDT, _usdpAmountIn);

        // USDT -> WETH
        predictedAssetAmount = TRICRYPTO2_POOL.get_dy(TRICRYPTO2_USDT, TRICRYPTO2_WETH, usdtAmount);
    }

    function predictUsdpOut(address _asset, uint256 _assetAmountIn) external view override returns (uint predictedUsdpAmount) {
        require(_asset == address(WETH), "Unit Protocol Swappers: UNSUPPORTED_ASSET");

        // WETH -> USDT
        uint usdtAmount = TRICRYPTO2_POOL.get_dy(TRICRYPTO2_WETH, TRICRYPTO2_USDT, _assetAmountIn);

        // USDT -> USDP
        predictedUsdpAmount = USDP_3CRV_POOL.get_dy_underlying(USDP_3CRV_POOL_USDT, USDP_3CRV_POOL_USDP, usdtAmount);
    }

    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        external override nonReentrant returns (uint swappedAssetAmount)
    {
        require(_asset == address(WETH), "Unit Protocol Swappers: UNSUPPORTED_ASSET");
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Swappers: AUTH_FAILED");

        // get USDP from user
        TransferHelper.safeTransferFrom(address(USDP), _user, address(this), _usdpAmount);

        // USDP -> USDT
        uint usdtAmount = USDP_3CRV_POOL.exchange_underlying(USDP_3CRV_POOL_USDP, USDP_3CRV_POOL_USDT, _usdpAmount, 0);

        // USDT -> WETH
        TRICRYPTO2_POOL.exchange(TRICRYPTO2_USDT, TRICRYPTO2_WETH, usdtAmount, 0, false);
        swappedAssetAmount = WETH.balanceOf(address(this));

        // WETH -> user
        TransferHelper.safeTransfer(address(WETH), _user, swappedAssetAmount);

        require(swappedAssetAmount >= _minAssetAmount, "Unit Protocol Swapper: INVALID_SWAP");
        return swappedAssetAmount;
    }

    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        external override nonReentrant returns (uint swappedUsdpAmount)
    {
        require(_asset == address(WETH), "Unit Protocol Swappers: UNSUPPORTED_ASSET");
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Swappers: AUTH_FAILED");

        // get WETH from user
        TransferHelper.safeTransferFrom(address(WETH), _user, address(this), _assetAmount);

        // WETH -> USDT
        TRICRYPTO2_POOL.exchange(TRICRYPTO2_WETH, TRICRYPTO2_USDT, _assetAmount, 0, false);
        uint usdtAmount = USDT.balanceOf(address(this));

        // USDT -> USDP
        swappedUsdpAmount = USDP_3CRV_POOL.exchange_underlying(USDP_3CRV_POOL_USDT, USDP_3CRV_POOL_USDP, usdtAmount, 0);

        // USDP -> user
        TransferHelper.safeTransfer(address(USDP), _user, swappedUsdpAmount);

        require(swappedUsdpAmount >= _minUsdpAmount, "Unit Protocol Swappers: INVALID_SWAP");
        return swappedUsdpAmount;
    }
}
