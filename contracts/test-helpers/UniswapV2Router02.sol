// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import '../helpers/IUniswapV2Factory.sol';
import '../helpers/IUniswapV2PairFull.sol';
import '../helpers/ERC20Like.sol';
import '../helpers/TransferHelper.sol';

import './UniswapV2Library.sol';
import '../interfaces/IWETH.sol';

/* 
 * @title UniswapV2Router02
 * @dev Implementation of the Uniswap V2 Router, facilitating liquidity addition and removal, and token swaps.
 */
contract UniswapV2Router02 {
    using SafeMath for uint;

    address public immutable factory;
    address payable public immutable weth;

    /* 
     * @dev Modifier to ensure the transaction is executed before the deadline.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    /* 
     * @notice Constructs the UniswapV2Router02 contract.
     * @param _factory The address of the Uniswap V2 factory contract.
     * @param _WETH The address of the Wrapped Ether (WETH) contract.
     */
    constructor(address _factory, address payable _WETH) {
        factory = _factory;
        weth = _WETH;
    }

    /* 
     * @dev Allows the router to receive ETH.
     */
    receive() external payable {
        assert(msg.sender == weth); // only accept ETH via fallback from the WETH contract
    }

    /* 
     * @dev Internal function to add liquidity.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @param amountADesired Desired amount of token A to add as liquidity.
     * @param amountBDesired Desired amount of token B to add as liquidity.
     * @param amountAMin Minimum amount of token A to add as liquidity.
     * @param amountBMin Minimum amount of token B to add as liquidity.
     * @return amountA The actual amount of token A added as liquidity.
     * @return amountB The actual amount of token B added as liquidity.
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /* 
     * @notice Adds liquidity for a token pair.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @param amountADesired Desired amount of token A to add as liquidity.
     * @param amountBDesired Desired amount of token B to add as liquidity.
     * @param amountAMin Minimum amount of token A to add as liquidity.
     * @param amountBMin Minimum amount of token B to add as liquidity.
     * @param to The address that will receive the liquidity tokens.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amountA The actual amount of token A added as liquidity.
     * @return amountB The actual amount of token B added as liquidity.
     * @return liquidity The amount of liquidity tokens minted.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IUniswapV2PairFull(pair).mint(to);
    }

    /* 
     * @notice Adds liquidity for a token and ETH pair.
     * @param token The address of the token.
     * @param amountTokenDesired Desired amount of token to add as liquidity.
     * @param amountTokenMin Minimum amount of token to add as liquidity.
     * @param amountETHMin Minimum amount of ETH to add as liquidity.
     * @param to The address that will receive the liquidity tokens.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amountToken The actual amount of token added as liquidity.
     * @return amountETH The actual amount of ETH added as liquidity.
     * @return liquidity The amount of liquidity tokens minted.
     */
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            weth,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = UniswapV2Library.pairFor(factory, token, weth);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(weth).deposit{value: amountETH}();
        assert(IWETH(weth).transfer(pair, amountETH));
        liquidity = IUniswapV2PairFull(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****

    /*
     * @notice Removes liquidity from a token pair and returns the underlying tokens to the caller.
     * @param tokenA The address of the first token in the liquidity pair.
     * @param tokenB The address of the second token in the liquidity pair.
     * @param liquidity The amount of liquidity tokens to remove.
     * @param amountAMin The minimum amount of token A that must be received for the transaction not to revert.
     * @param amountBMin The minimum amount of token B that must be received for the transaction not to revert.
     * @param to The address to which the withdrawn tokens should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amountA The amount of token A received.
     * @return amountB The amount of token B received.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        IUniswapV2PairFull(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IUniswapV2PairFull(pair).burn(to);
        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }

    /*
     * @notice Removes liquidity from a ETH/token pair and returns the underlying tokens and ETH to the caller.
     * @param token The address of the ERC-20 token in the liquidity pair.
     * @param liquidity The amount of liquidity tokens to remove.
     * @param amountTokenMin The minimum amount of token that must be received for the transaction not to revert.
     * @param amountETHMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param to The address to which the withdrawn tokens and ETH should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amountToken The amount of token received.
     * @return amountETH The amount of ETH received.
     */
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            weth,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(weth).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /*
     * @notice Allows a user to remove liquidity with a permit, bypassing the approval step.
     * @param tokenA The address of the first token in the liquidity pair.
     * @param tokenB The address of the second token in the liquidity pair.
     * @param liquidity The amount of liquidity tokens to remove.
     * @param amountAMin The minimum amount of token A that must be received for the transaction not to revert.
     * @param amountBMin The minimum amount of token B that must be received for the transaction not to revert.
     * @param to The address to which the withdrawn tokens should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @param approveMax Boolean indicating whether to approve the maximum amount or exact liquidity amount.
     * @param v Component of the signature.
     * @param r Component of the signature.
     * @param s Component of the signature.
     * @return amountA The amount of token A received.
     * @return amountB The amount of token B received.
     */
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountA, uint amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        IUniswapV2PairFull(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    /*
     * @notice Similar to `removeLiquidity`, but for ETH/token pairs and allows the use of a permit.
     * @param token The address of the ERC-20 token in the liquidity pair.
     * @param liquidity The amount of liquidity tokens to remove.
     * @param amountTokenMin The minimum amount of token that must be received for the transaction not to revert.
     * @param amountETHMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param to The address to which the withdrawn tokens and ETH should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @param approveMax Boolean indicating whether to approve the maximum amount or exact liquidity amount.
     * @param v Component of the signature.
     * @param r Component of the signature.
     * @param s Component of the signature.
     * @return amountToken The amount of token received.
     * @return amountETH The amount of ETH received.
     */
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountToken, uint amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, weth);
        uint value = approveMax ? uint(-1) : liquidity;
        IUniswapV2PairFull(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****

    /*
     * @notice Similar to `removeLiquidity`, but for ETH/token pairs and allows the use of a permit.
     * @param token The address of the ERC-20 token in the liquidity pair.
     * @param liquidity The amount of liquidity tokens to remove.
     * @param amountTokenMin The minimum amount of token that must be received for the transaction not to revert.
     * @param amountETHMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param to The address to which the withdrawn tokens and ETH should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @param approveMax Boolean indicating whether to approve the maximum amount or exact liquidity amount.
     * @param v Component of the signature.
     * @param r Component of the signature.
     * @param s Component of the signature.
     * @return amountToken The amount of token received.
     * @return amountETH The amount of ETH received.
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
        weth,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, ERC20Like(token).balanceOf(address(this)));
        IWETH(weth).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /*
     * @notice Allows the removal of liquidity with a permit for a token pair that supports fee-on-transfer.
     * @param token The address of the ERC-20 token in the liquidity pair that supports fee-on-transfer.
     * @param liquidity The amount of liquidity tokens to remove.
     * @param amountTokenMin The minimum amount of token that must be received for the transaction not to revert.
     * @param amountETHMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param to The address to which the withdrawn tokens and ETH should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @param approveMax Boolean indicating whether to approve the maximum amount or exact liquidity amount.
     * @param v Component of the signature.
     * @param r Component of the signature.
     * @param s Component of the signature.
     * @return amountETH The amount of ETH received after removing liquidity.
     */
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, weth);
        uint value = approveMax ? uint(-1) : liquidity;
        IUniswapV2PairFull(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    /*
     * @notice Allows the removal of liquidity with a permit for a token pair that supports fee-on-transfer.
     * @param token The address of the ERC-20 token in the liquidity pair that supports fee-on-transfer.
     * @param liquidity The amount of liquidity tokens to remove.
     * @param amountTokenMin The minimum amount of token that must be received for the transaction not to revert.
     * @param amountETHMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param to The address to which the withdrawn tokens and ETH should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @param approveMax Boolean indicating whether to approve the maximum amount or exact liquidity amount.
     * @param v Component of the signature.
     * @param r Component of the signature.
     * @param s Component of the signature.
     * @return amountETH The amount of ETH received after removing liquidity.
     */
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2PairFull(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    /*
     * @notice Swaps an exact amount of input tokens for as many output tokens as possible, adhering to the specified minimum output amount.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path An array of token addresses. This array will encode the path of the swap.
     * @param to The address to which the output tokens should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amounts The amounts of each token involved in the swaps.
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
        path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    /*
     * @notice Swaps tokens for as few input tokens as possible, exactly meeting the desired output amount.
     * @param amountOut The amount of output tokens to receive.
     * @param amountInMax The maximum amount of input tokens that can be sent.
     * @param path An array of token addresses. This array will encode the path of the swap.
     * @param to The address to which the output tokens should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amounts The amounts of each token involved in the swaps.
     */
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
        path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    /*
     * @notice Swaps an exact amount of ETH for as many output tokens as possible, adhering to the specified minimum output amount.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path An array of token addresses. This array will encode the path of the swap. The first element must be WETH.
     * @param to The address to which the output tokens should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amounts The amounts of each token involved in the swaps.
     */
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
    returns (uint[] memory amounts)
    {
        require(path[0] == weth, 'UniswapV2Router: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(weth).deposit{value: amounts[0]}();
        assert(IWETH(weth).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    /*
     * @notice Swaps tokens for as much ETH as possible, adhering to the specified minimum amount of ETH.
     * @param amountOut The amount of ETH to receive.
     * @param amountInMax The maximum amount of input tokens that can be sent.
     * @param path An array of token addresses. This array will encode the path of the swap. The last element must be WETH.
     * @param to The address to which the ETH should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amounts The amounts of each token involved in the swaps.
     */
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
    returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == weth, 'UniswapV2Router: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(weth).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /*
     * @notice Swaps an exact amount of input tokens for ETH.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param path An array of token addresses. This array will encode the path of the swap. The last element must be WETH.
     * @param to The address to which the ETH should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amounts The amounts of each token involved in the swaps.
     */
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
    returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == weth, 'UniswapV2Router: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(weth).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /*
     * @notice Swaps as much ETH as possible to exactly meet the desired amount of output tokens.
     * @param amountOut The amount of output tokens to receive.
     * @param path An array of token addresses. This array will encode the path of the swap. The first element must be WETH.
     * @param to The address to which the output tokens should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @return amounts The amounts of each token involved in the swaps.
     */
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == weth, 'UniswapV2Router: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        IWETH(weth).deposit{value: amounts[0]}();
        assert(IWETH(weth).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair

    /*
     * @notice Internal function to execute a swap for a given path, supporting tokens with a fee-on-transfer mechanism.
     * @param path An array of token addresses representing the path of the swap.
     * @param _to The address to which the output tokens should be sent.
     * @dev This function assumes that the initial amount of the input token has already been sent to the first pair.
     */
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            IUniswapV2PairFull pair = IUniswapV2PairFull(UniswapV2Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1,) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = ERC20Like(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /*
     * @notice Swaps an exact amount of input tokens for as many output tokens as possible, adhering to the specified minimum output amount and supporting fee-on-transfer tokens.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path An array of token addresses, encoding the path of the swap. Fee-on-transfer tokens can be included in the path.
     * @param to The address to which the output tokens should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = ERC20Like(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            ERC20Like(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    /*
     * @notice Swaps an exact amount of ETH for as many output tokens as possible, adhering to the specified minimum output amount and supporting fee-on-transfer tokens.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path An array of token addresses, encoding the path of the swap. Fee-on-transfer tokens can be included in the path. The first element must be WETH.
     * @param to The address to which the output tokens should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        payable
        ensure(deadline)
    {
        require(path[0] == weth, 'UniswapV2Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(weth).deposit{value: amountIn}();
        assert(IWETH(weth).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = ERC20Like(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            ERC20Like(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    /*
     * @notice Swaps an exact amount of input tokens for ETH, adhering to the specified minimum amount of ETH and supporting fee-on-transfer tokens.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param path An array of token addresses, encoding the path of the swap. Fee-on-transfer tokens can be included in the path. The last element must be WETH.
     * @param to The address to which the ETH should be sent.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        ensure(deadline)
    {
        require(path[path.length - 1] == weth, 'UniswapV2Router: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = ERC20Like(weth).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(weth).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****

    /*
     * @notice Provides an estimate for the amount of one token required to purchase a given amount of another token.
     * @param amountA The amount of the first token.
     * @param reserveA The reserve of the first token in the liquidity pool.
     * @param reserveB The reserve of the second token in the liquidity pool.
     * @return amountB The estimated amount of the second token that can be purchased with the given amount of the first token.
     */
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    /*
     * @notice Calculates the amount of output tokens one would receive given an input amount and the reserves of a pair.
     * @param amountIn The amount of input tokens.
     * @param reserveIn The reserve of the input token in the liquidity pool.
     * @param reserveOut The reserve of the output token in the liquidity pool.
     * @return amountOut The calculated amount of output tokens.
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /*
     * @notice Calculates the amount of input tokens one would need to provide to receive a specified amount of output tokens.
     * @param amountOut The desired amount of output tokens.
     * @param reserveIn The reserve of the input token in the liquidity pool.
     * @param reserveOut The reserve of the output token in the liquidity pool.
     * @return amountIn The calculated amount of input tokens required.
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /*
     * @notice Returns the amounts of each token in the path that the user would receive if they sent a specified amount of the first token in the path.
     * @param amountIn The amount of the first token in the path to send.
     * @param path An array of token addresses which form the path of the swap.
     * @return amounts The amounts of each token in the path that would be received.
     */
    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
    returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    /*
     * @notice Returns the amounts of each token in the path that a user would need to send to receive a specified amount of the last token in the path.
     * @param amountOut The desired amount of the last token in the path.
     * @param path An array of token addresses which form the path of the swap.
     * @return amounts The amounts of each token in the path that would need to be sent.
     */
    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
    returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
