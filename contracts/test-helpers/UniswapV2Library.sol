// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../helpers/SafeMath.sol";
import "../helpers/IUniswapV2PairFull.sol";

/**
 * @title UniswapV2Library
 * @dev Provides functions for interacting with UniswapV2 pairs.
 */
library UniswapV2Library {
    using SafeMath for uint;

    /**
     * @dev Sorts and returns token addresses in ascending order to avoid duplicates.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return token0 The address of the lower token.
     * @return token1 The address of the higher token.
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    /**
     * @dev Calculates the CREATE2 address for a pair without making any external calls.
     * @param factory The address of the Uniswap factory contract.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return pair The address of the Uniswap pair.
     */
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }

    /**
     * @dev Fetches and sorts the reserves for a pair.
     * @param factory The address of the Uniswap factory contract.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return reserveA The reserve of tokenA.
     * @return reserveB The reserve of tokenB.
     */
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2PairFull(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @dev Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset.
     * @param amountA The amount of tokenA.
     * @param reserveA The reserve of tokenA.
     * @param reserveB The reserve of tokenB.
     * @return amountB The equivalent amount of tokenB.
     */
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    /**
     * @dev Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset.
     * @param amountIn The input amount of the asset.
     * @param reserveIn The reserve of the input asset.
     * @param reserveOut The reserve of the output asset.
     * @return amountOut The maximum output amount.
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    /**
     * @dev Given an output amount of an asset and pair reserves, returns a required input amount of the other asset.
     * @param amountOut The output amount of the asset.
     * @param reserveIn The reserve of the input asset.
     * @param reserveOut The reserve of the output asset.
     * @return amountIn The required input amount.
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    /**
     * @dev Performs chained getAmountOut calculations on any number of pairs.
     * @param factory The address of the Uniswap factory contract.
     * @param amountIn The input amount of the asset.
     * @param path An array of token addresses.
     * @return amounts The output amounts of each token in the path.
     */
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @dev Performs chained getAmountIn calculations on any number of pairs.
     * @param factory The address of the Uniswap factory contract.
     * @param amountOut The output amount of the asset.
     * @param path An array of token addresses.
     * @return amounts The input amounts of each token in the path.
     */
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}