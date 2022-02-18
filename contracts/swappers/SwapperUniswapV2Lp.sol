// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;


import "../interfaces/swappers/ISwapper.sol";
import "./helpers/UniswapV2Helper.sol";
import "./AbstractSwapper.sol";
import "../interfaces/ICurveWith3crvPool.sol";
import "../interfaces/ICurveTricrypto2Pool.sol";
import "../helpers/SafeMath.sol";
import "../helpers/IUniswapV2PairFull.sol";
import '../helpers/TransferHelper.sol';
import "../helpers/ReentrancyGuard.sol";
import "../Auth2.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @dev swap usdp/any uniswapv2 lp
 */
contract SwapperUniswapV2Lp is AbstractSwapper {
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
    ) AbstractSwapper(_vaultParameters) {
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
        IUniswapV2PairFull pair = IUniswapV2PairFull(_asset);
        (uint256 pairWethId,, address underlyingToken) = UniswapV2Helper.getTokenInfo(pair, address(WETH));

        // USDP -> USDT
        uint usdtAmount = USDP_3CRV_POOL.get_dy_underlying(USDP_3CRV_POOL_USDP, USDP_3CRV_POOL_USDT, _usdpAmountIn);

        // USDT -> WETH
        uint wethAmount = TRICRYPTO2_POOL.get_dy(TRICRYPTO2_USDT, TRICRYPTO2_WETH, usdtAmount);

        // 1/2 WETH -> LP underlying token
        uint tokenAmount = UniswapV2Helper.calcAmountOutByTokenId(pair, pairWethId, wethAmount / 2);

        // 1/2 WETH + LP underlying token -> LP tokens
        (uint amount0, uint amount1) = (pairWethId == 0) ? (wethAmount, tokenAmount) : (tokenAmount, wethAmount);
        return UniswapV2Helper.calculateLpAmountAfterDepositTokens(pair, amount0, amount1);
    }

    function predictUsdpOut(address _asset, uint256 _assetAmountIn) external view override returns (uint predictedUsdpAmount) {
        IUniswapV2PairFull pair = IUniswapV2PairFull(_asset);
        (uint256 pairWethId, uint pairTokenId, address underlyingToken) = UniswapV2Helper.getTokenInfo(pair, address(WETH));

        // LP tokens -> WETH + LP underlying token
        (uint amount0, uint amount1) = UniswapV2Helper.calculateTokensAmountAfterWithdrawLp(pair, _assetAmountIn);
        (uint wethAmount, uint tokenAmount) = (pairWethId == 0) ? (amount0, amount1) : (amount1, amount0);

        // LP underlying token -> WETH
        wethAmount = wethAmount.add(UniswapV2Helper.calcAmountOutByTokenId(pair, pairTokenId, tokenAmount));

        // WETH -> USDT
        uint usdtAmount = TRICRYPTO2_POOL.get_dy(TRICRYPTO2_WETH, TRICRYPTO2_USDT, wethAmount);

        // USDT -> USDP
        predictedUsdpAmount = USDP_3CRV_POOL.get_dy_underlying(USDP_3CRV_POOL_USDT, USDP_3CRV_POOL_USDP, usdtAmount);
    }

    function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount)
        internal override returns (uint swappedAssetAmount)
    {
        IUniswapV2PairFull pair = IUniswapV2PairFull(_asset);
        (uint256 pairWethId,, address underlyingToken) = UniswapV2Helper.getTokenInfo(pair, address(WETH));

        // get USDP from user
        TransferHelper.safeTransferFrom(address(USDP), _user, address(this), _usdpAmount);

        { // stack to deep
            // USDP -> USDT
            uint usdtAmount = USDP_3CRV_POOL.exchange_underlying(USDP_3CRV_POOL_USDP, USDP_3CRV_POOL_USDT, _usdpAmount, 0);

            // USDT -> WETH
            TRICRYPTO2_POOL.exchange(TRICRYPTO2_USDT, TRICRYPTO2_WETH, usdtAmount, 0, false);
        }
        uint wethAmount = WETH.balanceOf(address(this));

        // 1/2 WETH -> LP underlying token
        // reserves supposed to be >> swap amount, so we can just swap 1/2 of weth
        // otherwise we won't get _minAssetAmount later
        uint tokenAmount = _swapPairTokens(pair, address(WETH), pairWethId, wethAmount / 2, address(this));

        // 1/2 WETH + LP underlying token -> LP tokens and send remainders to user
        swappedAssetAmount = _addLiquidity(pair, pairWethId, underlyingToken, wethAmount.sub(wethAmount / 2), tokenAmount, _user);

        return swappedAssetAmount;
    }

    function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount)
        internal override returns (uint swappedUsdpAmount)
    {
        IUniswapV2PairFull pair = IUniswapV2PairFull(_asset);
        (uint256 pairWethId, uint pairTokenId, address underlyingToken) = UniswapV2Helper.getTokenInfo(pair, address(WETH));

        // get LP tokens from user (directly to pair for next swap)
        TransferHelper.safeTransferFrom(_asset, _user, _asset, _assetAmount);

        // LP tokens -> WETH + LP underlying token
        (uint amount0, uint amount1) = pair.burn(address(this));
        (uint wethAmount, uint tokenAmount) = (pairWethId == 0) ? (amount0, amount1) : (amount1, amount0);

        // LP underlying token -> WETH
        wethAmount = wethAmount.add(_swapPairTokens(pair, underlyingToken, pairTokenId, tokenAmount, address(this)));

        // WETH -> USDT
        TRICRYPTO2_POOL.exchange(TRICRYPTO2_WETH, TRICRYPTO2_USDT, wethAmount, 0, false);
        uint usdtAmount = USDT.balanceOf(address(this));

        // USDT -> USDP
        swappedUsdpAmount = USDP_3CRV_POOL.exchange_underlying(USDP_3CRV_POOL_USDT, USDP_3CRV_POOL_USDP, usdtAmount, 0);

        // USDP -> user
        TransferHelper.safeTransfer(address(USDP), _user, swappedUsdpAmount);

        return swappedUsdpAmount;
    }

    function _swapPairTokens(IUniswapV2PairFull _pair, address _token, uint _tokenId, uint _amount, address _to) internal returns (uint tokenAmount) {
        tokenAmount = UniswapV2Helper.calcAmountOutByTokenId(_pair, _tokenId, _amount);
        TransferHelper.safeTransfer(_token, address(_pair), _amount);

        _pair.swap(_tokenId == 0 ? 0: tokenAmount, _tokenId == 1 ? 0 : tokenAmount, _to, new bytes(0));
    }

    function _addLiquidity(IUniswapV2PairFull _pair, uint _wethId, address _underlyingToken, uint _wethAmount, uint _tokenAmount, address _to) internal returns (uint lpAmount) {
        if (_wethId == 0) {
            (,, lpAmount) = UniswapV2Helper.addLiquidity(
                address(_pair),
                address(WETH), _underlyingToken,
                _wethAmount, _tokenAmount,
                _wethAmount.mul(99).div(100), _tokenAmount.mul(99).div(100),
                _to
            );
        } else {
            (,, lpAmount) = UniswapV2Helper.addLiquidity(
                address(_pair),
                _underlyingToken, address(WETH),
                _tokenAmount, _wethAmount,
                _tokenAmount.mul(99).div(100), _wethAmount.mul(99).div(100),
                _to
            );
        }

        // send possible remainders
        uint wethRemainder = WETH.balanceOf(address(this));
        if (wethRemainder > 0) {
            TransferHelper.safeTransfer(address(WETH), _to, wethRemainder);
        }

        uint tokenRemainder = IERC20(_underlyingToken).balanceOf(address(this));
        if (tokenRemainder > 0) {
            TransferHelper.safeTransfer(_underlyingToken, _to, tokenRemainder);
        }
    }
}
