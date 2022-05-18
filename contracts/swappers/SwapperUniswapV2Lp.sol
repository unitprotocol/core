// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;


import "../interfaces/swappers/ISwapper.sol";
import "./helpers/UniswapV2Helper.sol";
import "./AbstractSwapper.sol";
import "../interfaces/curve/ICurvePoolMeta.sol";
import "../interfaces/curve/ICurvePoolCrypto.sol";
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
    using UniswapV2Helper for IUniswapV2PairFull;
    using TransferHelper for address;

    address public immutable WETH;

    ISwapper public immutable wethSwapper;

    constructor(
        address _vaultParameters, address _weth,  address _usdp,
        address _wethSwapper
    ) AbstractSwapper(_vaultParameters, _usdp) {
        require(
            _weth != address(0)
            && _wethSwapper != address(0)
            , "Unit Protocol Swappers: ZERO_ADDRESS"
        );

        WETH = _weth;

        wethSwapper = ISwapper(_wethSwapper);
    }

    function predictAssetOut(address _asset, uint256 _usdpAmountIn) external view override returns (uint predictedAssetAmount) {
        IUniswapV2PairFull pair = IUniswapV2PairFull(_asset);
        (uint256 pairWethId,,) = pair.getTokenInfo(WETH);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        // USDP -> WETH
        uint wethAmount = wethSwapper.predictAssetOut(WETH, _usdpAmountIn);

        // ~1/2 WETH -> LP underlying token
        uint wethToSwap = pair.calcWethToSwapBeforeMint(wethAmount, pairWethId);
        uint tokenAmount = pair.calcAmountOutByTokenId(pairWethId, wethToSwap, reserve0, reserve1);

        // ~1/2 WETH + LP underlying token -> LP tokens
        uint wethToDeposit = wethAmount.sub(wethToSwap);
        if (pairWethId == 0) {
            predictedAssetAmount = pair.calculateLpAmountAfterDepositTokens(
                wethToDeposit, tokenAmount, uint(reserve0).add(wethToSwap), uint(reserve1).sub(tokenAmount)
            );
        } else {
            predictedAssetAmount = pair.calculateLpAmountAfterDepositTokens(
                tokenAmount, wethToDeposit, uint(reserve0).sub(tokenAmount), uint(reserve1).add(wethToSwap)
            );
        }
    }

    function predictUsdpOut(address _asset, uint256 _assetAmountIn) external view override returns (uint predictedUsdpAmount) {
        IUniswapV2PairFull pair = IUniswapV2PairFull(_asset);
        (uint256 pairWethId, uint pairTokenId,) = pair.getTokenInfo(WETH);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        // LP tokens -> WETH + LP underlying token
        (uint amount0, uint amount1) = pair.calculateTokensAmountAfterWithdrawLp(_assetAmountIn);
        (uint wethAmount, uint tokenAmount) = (pairWethId == 0) ? (amount0, amount1) : (amount1, amount0);

        // LP underlying token -> WETH
        wethAmount = wethAmount.add(
            pair.calcAmountOutByTokenId(pairTokenId, tokenAmount, uint(reserve0).sub(amount0), uint(reserve1).sub(amount1))
        );

        // WETH -> USDP
        predictedUsdpAmount = wethSwapper.predictUsdpOut(WETH, wethAmount);
    }

    function _swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 /** _minAssetAmount */)
        internal override returns (uint swappedAssetAmount)
    {
        IUniswapV2PairFull pair = IUniswapV2PairFull(_asset);
        (uint256 pairWethId,, address underlyingToken) = pair.getTokenInfo(WETH);

        // USDP -> WETH
        address(USDP).safeTransfer(address(wethSwapper), _usdpAmount);
        uint wethAmount = wethSwapper.swapUsdpToAssetWithDirectSending(address(this), WETH, _usdpAmount, 0);


        // ~1/2 WETH -> LP underlying token
        uint wethToSwap = pair.calcWethToSwapBeforeMint(wethAmount, pairWethId);
        uint tokenAmount = _swapPairTokens(pair, WETH, pairWethId, wethToSwap, address(this));

        // ~1/2 WETH + LP underlying token -> LP tokens and send remainders to user
        WETH.safeTransfer(address(pair), wethAmount.sub(wethToSwap));
        underlyingToken.safeTransfer(address(pair), tokenAmount);
        swappedAssetAmount = pair.mint(_user);
    }

    function _swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 /** _minUsdpAmount */)
        internal override returns (uint swappedUsdpAmount)
    {
        IUniswapV2PairFull pair = IUniswapV2PairFull(_asset);
        (uint256 pairWethId, uint pairTokenId, address underlyingToken) = pair.getTokenInfo(WETH);

        // LP tokens -> WETH + LP underlying token
        _asset.safeTransfer(_asset, _assetAmount);
        (uint amount0, uint amount1) = pair.burn(address(this));
        (uint wethAmount, uint tokenAmount) = (pairWethId == 0) ? (amount0, amount1) : (amount1, amount0);

        // LP underlying token -> WETH
        wethAmount = wethAmount.add(_swapPairTokens(pair, underlyingToken, pairTokenId, tokenAmount, address(this)));

        // WETH -> USDP
        WETH.safeTransfer(address(wethSwapper), wethAmount);
        swappedUsdpAmount = wethSwapper.swapAssetToUsdpWithDirectSending(address(this), WETH, wethAmount, 0);

        // USDP -> user
        address(USDP).safeTransfer(_user, swappedUsdpAmount);
    }

    function _swapPairTokens(IUniswapV2PairFull _pair, address _token, uint _tokenId, uint _amount, address _to) internal returns (uint tokenAmount) {
        tokenAmount = _pair.calcAmountOutByTokenId(_tokenId, _amount);
        TransferHelper.safeTransfer(_token, address(_pair), _amount);

        _pair.swap(_tokenId == 0 ? 0: tokenAmount, _tokenId == 1 ? 0 : tokenAmount, _to, new bytes(0));
    }
}
