// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../../helpers/IUniswapV2Factory.sol";
import "../../helpers/IUniswapV2PairFull.sol";
import '../../helpers/TransferHelper.sol';
import "../../helpers/SafeMath.sol";
import "../../helpers/Math.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev several methods for calculations different uniswap v2 params. Part of them extracted for uniswap contracts
 * @dev for original licenses see attached links
 */
library UniswapV2Helper {
    using SafeMath for uint;

    /**
     * given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
     * see https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
     */
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'Unit Protocol Swappers: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'Unit Protocol Swappers: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    /**
     * given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
     * see https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'Unit Protocol Swappers: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'Unit Protocol Swappers: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    /**
     * @dev modified version from UniswapV2Router02 to use existing pair address + direct transfers of token
     * see https://docs.uniswap.org/protocol/V2/guides/smart-contract-integration/providing-liquidity
     * see https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol
     */
    function addLiquidity(
        address pair,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) internal returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(pair, amountADesired, amountBDesired, amountAMin, amountBMin);
        TransferHelper.safeTransfer(tokenA, pair, amountA);
        TransferHelper.safeTransfer(tokenB, pair, amountB);
        liquidity = IUniswapV2PairFull(pair).mint(to);
    }

    /**
     * @dev modified version from UniswapV2Router02 to use existing pair address
     * see https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol
     */
    function _addLiquidity(
        address pair,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint amountA, uint amountB) {
        (uint112 reserveA, uint112 reserveB, ) = IUniswapV2PairFull(pair).getReserves();
        require(reserveA > 0 && reserveB > 0, 'Unit Protocol Swappers: ZERO_RESERVES');

        uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
        if (amountBOptimal <= amountBDesired) {
            require(amountBOptimal >= amountBMin, 'Unit Protocol Swappers: INSUFFICIENT_B_AMOUNT');
            (amountA, amountB) = (amountADesired, amountBOptimal);
        } else {
            uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
            assert(amountAOptimal <= amountADesired);
            require(amountAOptimal >= amountAMin, 'Unit Protocol Swappers: INSUFFICIENT_A_AMOUNT');
            (amountA, amountB) = (amountAOptimal, amountBDesired);
        }
    }

    /**
     * see pair._mintFee in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
     */
    function getLPAmountAddedDuringFeeMint(IUniswapV2PairFull pair, uint112 _reserve0, uint112 _reserve1) internal view returns (uint) {
        address feeTo = IUniswapV2Factory(pair.factory()).feeTo();
        bool feeOn = feeTo != address(0);

        uint _kLast = pair.kLast(); // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = pair.totalSupply().mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    return liquidity;
                }
            }
        }

        return 0;
    }

    /**
     * see pair.mint in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
     */
    function calculateLpAmountAfterDepositTokens(IUniswapV2PairFull pair, uint amount0, uint amount1) internal view returns (uint) {
        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();

        uint _totalSupply = pair.totalSupply().add(getLPAmountAddedDuringFeeMint(pair, _reserve0, _reserve1));

        return Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
    }

    /**
     * see pair.burn in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
     */
    function calculateTokensAmountAfterWithdrawLp(IUniswapV2PairFull pair, uint lpAmount) internal view returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();
        address _token0 = pair.token0();
        address _token1 = pair.token1();
        uint balance0 = IERC20(_token0).balanceOf(address(pair));
        uint balance1 = IERC20(_token1).balanceOf(address(pair));

        uint _totalSupply = pair.totalSupply().add(getLPAmountAddedDuringFeeMint(pair, _reserve0, _reserve1));
        amount0 = lpAmount.mul(balance0) / _totalSupply;
        amount1 = lpAmount.mul(balance1) / _totalSupply;
    }

    function getTokenInfo(IUniswapV2PairFull pair, address _token) internal view returns (uint tokenId, uint secondTokenId, address secondToken) {
        if (pair.token0() == _token) {
            return (0, 1, pair.token1());
        } else if (pair.token1() == _token) {
            return (1, 0, pair.token0());
        } else {
            revert("Unit Protocol Swappers: UNSUPPORTED_PAIR");
        }
    }

    function calcAmountOutByTokenId(IUniswapV2PairFull _pair, uint _tokenId, uint _amount) internal view returns (uint) {
        (uint112 reserve0, uint112 reserve1, ) = _pair.getReserves();

        uint256 reserveIn;
        uint256 reserveOut;
        if (_tokenId == 0) {
            reserveIn = reserve0;
            reserveOut = reserve1;
        } else { // the fact that pair has weth must be checked outside
            reserveIn = reserve1;
            reserveOut = reserve0;
        }

        return UniswapV2Helper.getAmountOut(_amount, reserveIn, reserveOut);
    }
}
