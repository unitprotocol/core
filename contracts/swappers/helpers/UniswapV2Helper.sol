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
 * @title UniswapV2Helper
 * @dev Library providing functions to interact with UniswapV2 protocol.
 * @dev several methods for calculations different uniswap v2 params. Part of them extracted for uniswap contracts
 * @dev for original licenses see attached links
 */
library UniswapV2Helper {
    using SafeMath for uint;

    /**
     * @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset.
     * see https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
     * @param amountA The amount of the first asset.
     * @param reserveA The reserve of the first asset in the pair.
     * @param reserveB The reserve of the second asset in the pair.
     * @return amountB The equivalent amount of the second asset.
     */
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'Unit Protocol Swappers: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'Unit Protocol Swappers: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    /**
     * @notice Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset.
     * see https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
     * @param amountIn The amount of the input asset.
     * @param reserveIn The reserve of the input asset.
     * @param reserveOut The reserve of the output asset.
     * @return amountOut The maximum output amount of the output asset.
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
     * @notice Calculates the amount of LP tokens added during the fee minting process.
     * see pair._mintFee in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
     * @param pair The UniswapV2 pair contract.
     * @param _reserve0 The reserve of the first token.
     * @param _reserve1 The reserve of the second token.
     * @return The amount of LP tokens added during fee minting.
     */
    function getLPAmountAddedDuringFeeMint(IUniswapV2PairFull pair, uint _reserve0, uint _reserve1) internal view returns (uint) {
        address feeTo = IUniswapV2Factory(pair.factory()).feeTo();
        bool feeOn = feeTo != address(0);

        uint _kLast = pair.kLast(); // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(_reserve0.mul(_reserve1));
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
     * @notice Calculates the amount of LP tokens that will be received after depositing tokens to the pool.
     * see pair.mint in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
     * @param _pair The UniswapV2 pair contract.
     * @param _amount0 The amount of the first token being deposited.
     * @param _amount1 The amount of the second token being deposited.
     * @return The amount of LP tokens that will be received.
     */
    function calculateLpAmountAfterDepositTokens(IUniswapV2PairFull _pair, uint _amount0, uint _amount1) internal view returns (uint) {
        (uint112 reserve0, uint112 reserve1,) = _pair.getReserves();
        return calculateLpAmountAfterDepositTokens(_pair, _amount0, _amount1, reserve0, reserve1);
    }

    /**
     * @notice Calculates the amount of LP tokens that will be received after depositing tokens to the pool with specific reserves.
     * @param _pair The UniswapV2 pair contract.
     * @param _amount0 The amount of the first token being deposited.
     * @param _amount1 The amount of the second token being deposited.
     * @param _reserve0 The reserve of the first token.
     * @param _reserve1 The reserve of the second token.
     * @return The amount of LP tokens that will be received.
     */
    function calculateLpAmountAfterDepositTokens(
        IUniswapV2PairFull _pair, uint _amount0, uint _amount1, uint _reserve0, uint _reserve1
    ) internal view returns (uint) {
        uint _totalSupply = _pair.totalSupply().add(getLPAmountAddedDuringFeeMint(_pair, _reserve0, _reserve1));
        if (_totalSupply == 0) {
            return Math.sqrt(_amount0.mul(_amount1)).sub(_pair.MINIMUM_LIQUIDITY());
        }

        return Math.min(_amount0.mul(_totalSupply) / _reserve0, _amount1.mul(_totalSupply) / _reserve1);
    }

    /**
     * @notice Calculates the token amounts that will be received after withdrawing LP tokens from the pool.
     * see pair.burn in pair contract https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
     * @param pair The UniswapV2 pair contract.
     * @param lpAmount The amount of LP tokens being withdrawn.
     * @return amount0 The amount of the first token that will be received.
     * @return amount1 The amount of the second token that will be received.
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

    /**
     * @notice Retrieves token information for a UniswapV2 pair given a token address.
     * @param pair The UniswapV2 pair contract.
     * @param _token The address of the token for which information is needed.
     * @return tokenId The ID of the token in the pair (0 or 1).
     * @return secondTokenId The ID of the other token in the pair (0 or 1).
     * @return secondToken The address of the other token in the pair.
     */
    function getTokenInfo(IUniswapV2PairFull pair, address _token) internal view returns (uint tokenId, uint secondTokenId, address secondToken) {
        if (pair.token0() == _token) {
            return (0, 1, pair.token1());
        } else if (pair.token1() == _token) {
            return (1, 0, pair.token0());
        } else {
            revert("Unit Protocol Swappers: UNSUPPORTED_PAIR");
        }
    }

    /**
     * @notice Calculates the output amount of a token swap given the token ID and amount.
     * @param _pair The UniswapV2 pair contract.
     * @param _tokenId The ID of the token being swapped.
     * @param _amount The amount of the token being swapped.
     * @return The output amount of the token swap.
     */
    function calcAmountOutByTokenId(IUniswapV2PairFull _pair, uint _tokenId, uint _amount) internal view returns (uint) {
        (uint112 reserve0, uint112 reserve1, ) = _pair.getReserves();

        return calcAmountOutByTokenId(_pair, _tokenId, _amount, uint(reserve0), uint(reserve1));
    }

    /**
     * @notice Calculates the output amount of a token swap given the token ID, amount and specific reserves.
     * @param _tokenId The ID of the token being swapped.
     * @param _amount The amount of the token being swapped.
     * @param reserve0 The reserve of the first token.
     * @param reserve1 The reserve of the second token.
     * @return The output amount of the token swap.
     */
    function calcAmountOutByTokenId(IUniswapV2PairFull /* _pair */, uint _tokenId, uint _amount, uint reserve0, uint reserve1) internal pure returns (uint) {
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

    /**
     * @notice Calculates the amount of WETH to swap before minting LP tokens when only WETH is available.
     * @param _pair The UniswapV2 pair contract.
     * @param _wethAmount The total amount of WETH available for swapping and adding liquidity.
     * @param _pairWethId The ID of WETH in the UniswapV2 pair.
     * @return wethToSwap The amount of WETH to swap to balance the token amounts for adding liquidity.
     */
    function calcWethToSwapBeforeMint(IUniswapV2PairFull _pair, uint _wethAmount, uint _pairWethId) internal view returns (uint wethToSwap) {
        (uint112 reserve0, uint112 reserve1, ) = _pair.getReserves();
        uint wethReserve = _pairWethId == 0 ? uint(reserve0) : uint(reserve1);

        return Math.sqrt(
            wethReserve.mul(
                wethReserve.mul(3988009).add(
                    _wethAmount.mul(3988000)
                )
            )
        ).sub(
            wethReserve.mul(1997)
        ).div(1994);

        /*
            we have several equations
            ```
            syms wethToChange  wethReserve tokenReserve wethAmount wethToAdd tokenChanged tokenToAdd wethReserve2 tokenReserve2
            % we have `wethAmount` amount, `wethToChange` we want to change for `tokenChanged`, `wethToAdd` we will deposit for minting LP
            eqn1 = wethAmount == wethToChange + wethToAdd
            % all `tokenChanged` which we got from exchange we want to deposit for minting LP
            eqn2 = tokenToAdd == tokenChanged
            % formula from swap
            eqn3 = ((wethReserve + wethToChange) * 1000 - wethToChange * 3) * (tokenReserve - tokenChanged) * 1000 = wethReserve * tokenReserve * 1000 * 1000
            % after change we have such reserves:
            eqn4 = wethReserve2 == (wethReserve + wethToChange)
            eqn5 = tokenReserve2 == (tokenReserve - tokenChanged)
            % depositing in current reserves ratio (both parts of min must be equal `Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);`)
            eqn6 = wethToAdd / tokenToAdd == wethReserve2 / tokenReserve2
            S = solve(eqn6, wethToChange)
            ```

            lets transform equations to substitute variables in eqn6
            step 1:
            ```
            syms wethToChange  wethReserve tokenReserve wethAmount wethToAdd tokenChanged tokenToAdd wethReserve2 tokenReserve2
            eqn1 = wethToAdd == (wethAmount - wethToChange)
            eqn2 = tokenToAdd == tokenChanged
            %eqn3 = ((wethReserve + wethToChange) * 1000 - wethToChange * 3) * (tokenReserve - tokenChanged) = wethReserve * tokenReserve * 1000
            %eqn3 = (wethReserve * 1000 + wethToChange * 997) * (tokenReserve - tokenChanged) = wethReserve * tokenReserve * 1000
            %eqn3 = (tokenReserve - tokenChanged) = wethReserve * tokenReserve * 1000 / (wethReserve * 1000 + wethToChange * 997)
            eqn3 = tokenChanged = (tokenReserve - wethReserve * tokenReserve * 1000 / (wethReserve * 1000 + wethToChange * 997))
            eqn4 = wethReserve2 == (wethReserve + wethToChange)
            eqn5 = tokenReserve2 == (tokenReserve - tokenChanged)
            eqn6 = wethToAdd / tokenChanged == (wethReserve + wethToChange) / (tokenReserve - tokenChanged)
            S = solve(eqn6, wethToChange)
            ```

            step 2: substitute variables from eqn1-eqn5 in eqn6
            ```
            syms wethToChange  wethReserve tokenReserve wethAmount wethToAdd tokenChanged tokenToAdd wethReserve2 tokenReserve2
            eqn6 = (wethAmount - wethToChange) / (tokenReserve - wethReserve * tokenReserve * 1000 / (wethReserve * 1000 + wethToChange * 997)) == (wethReserve + wethToChange) / (tokenReserve - (tokenReserve - wethReserve * tokenReserve * 1000 / (wethReserve * 1000 + wethToChange * 997)))
            S = solve(eqn6, wethToChange)
            ```

            result = sqrt(wethReserve*(3988009*wethReserve + 3988000*wethAmount))/1994 - (1997*wethReserve)/1994
        */
    }
}