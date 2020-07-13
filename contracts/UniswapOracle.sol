// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "./helpers/SafeMath.sol";
import "./helpers/ERC20Like.sol";
import "./helpers/IUniswapV2Factory.sol";


/**
 * @title UniswapOracle
 * @dev Calculates the USD price of desired tokens
 **/
contract UniswapOracle {

    using SafeMath for uint;

    address public DAI;
    address public USDC;
    address public WETH;
    address public DAIWETH;
    address public USDCWETH;
    IUniswapV2Factory public uniswapFactory;

    constructor(
        address factory,
        address dai,
        address usdc,
        address weth
    ) public {
        uniswapFactory = IUniswapV2Factory(factory);
        DAI = dai;
        USDC = usdc;
        WETH = weth;
        DAIWETH = uniswapFactory.getPair(DAI, WETH);
        USDCWETH = uniswapFactory.getPair(USDC, WETH);
    }

    /**
     * @notice USD token's rate is calculated as the product of the token price in ETH and ETH price in USD
     * @notice {Token}/WETH pair must be registered on Uniswap
     * @param token The token address
     * @param amount Amount of tokens
     * @return price of tokens in USD (with 18 decimals)
     **/
    function tokenToUsd(address token, uint amount) external view returns (uint) {
        address uniswapPair = uniswapFactory.getPair(token, WETH);
        require(uniswapPair != address(0), "USDP: UNISWAP_PAIR_DOES_NOT_EXIST");

        // token reserve of {Token}/WETH pool
        uint tokenReserve = ERC20Like(token).balanceOf(uniswapPair);

        // revert if there is no liquidity
        require(tokenReserve > 0, "USDP: UNISWAP_EMPTY_POOL");

        // WETH reserve of {Token}/WETH pool
        uint wethReserve = ERC20Like(WETH).balanceOf(uniswapPair);

        (uint ethUsdNum, uint ethUsdDenom) = ethUsd();

        return amount.mul(wethReserve).mul(ethUsdNum).div(tokenReserve).div(ethUsdDenom);
    }

    /**
     * @notice ETH/USD rate is calculated as avg rate between ETH/DAI & ETH/USDC
     * returns Two values representing ETH price in USD: numerator & denominator
     **/
    function ethUsd() public view returns (uint, uint) {
        // DAI reserve of DAI/WETH pool
        uint daiReserve = ERC20Like(DAI).balanceOf(DAIWETH);

        // WETH reserve of DAI/WETH pool
        uint wethReserveDai = ERC20Like(WETH).balanceOf(DAIWETH);

        // USDC reserve of USDC/WETH pool
        // USDC has only 6 decimals, so multiply by 10^12 to get the same accuracy as DAI
        uint usdcReserve = ERC20Like(USDC).balanceOf(USDCWETH).mul(10 ** 12);

        // WETH reserve of USDC/WETH pool
        uint wethReserveUSDC = ERC20Like(WETH).balanceOf(USDCWETH);

        return (daiReserve.add(usdcReserve), wethReserveDai.add(wethReserveUSDC));
    }
}
