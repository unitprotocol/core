// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../helpers/ERC20Like.sol";
import "../helpers/SafeMath.sol";
import "../interfaces/IAggregator.sol";
import "../helpers/IUniswapV2Factory.sol";
import "../oracles/OracleSimple.sol";

/**
 * @title Keep3rOracleMainAsset_Mock
 * @dev Mock contract for calculating the USD price of desired tokens. This contract is for testing purposes only.
 */
contract Keep3rOracleMainAsset_Mock is ChainlinkedOracleSimple {
    using SafeMath for uint;

    uint public immutable Q112 = 2 ** 112;
    uint public immutable ETH_USD_DENOMINATOR = 100000000;

    IAggregator public immutable ethUsdChainlinkAggregator;

    IUniswapV2Factory public immutable uniswapFactory;

    /**
     * @notice Creates a Keep3rOracleMainAsset_Mock contract.
     * @param uniFactory The Uniswap V2 Factory address.
     * @param weth The Wrapped Ether (WETH) token address.
     * @param chainlinkAggregator The Chainlink aggregator address for ETH/USD price feed.
     */
    constructor(
        IUniswapV2Factory uniFactory,
        address weth,
        IAggregator chainlinkAggregator
    ) {
        require(address(uniFactory) != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(weth != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(address(chainlinkAggregator) != address(0), "Unit Protocol: ZERO_ADDRESS");

        uniswapFactory = uniFactory;
        WETH = weth;
        ethUsdChainlinkAggregator = chainlinkAggregator;
    }

    /**
     * @notice Converts the asset amount to its equivalent USD value.
     * @param asset The address of the asset token.
     * @param amount The amount of the asset to convert.
     * @return usdValue The equivalent USD value of the input asset amount.
     * @dev Override with mock; only for tests. This function is mocked for testing and should not be used for accurate pricing.
     */
    function assetToUsd(address asset, uint amount) public override view returns (uint usdValue) {
        if (asset == WETH) {
            return ethToUsd(amount);
        }

        address uniswapPair = uniswapFactory.getPair(asset, WETH);
        require(uniswapPair != address(0), "Unit Protocol: UNISWAP_PAIR_DOES_NOT_EXIST");

        // token reserve of {Token}/WETH pool
        uint tokenReserve = ERC20Like(asset).balanceOf(uniswapPair);

        // revert if there is no liquidity
        require(tokenReserve != 0, "Unit Protocol: UNISWAP_EMPTY_POOL");

        // WETH reserve of {Token}/WETH pool
        uint wethReserve = ERC20Like(WETH).balanceOf(uniswapPair);

        uint wethResult = amount.mul(wethReserve);

        return ethToUsd(wethResult).mul(Q112).div(tokenReserve);
    }

    /**
     * @notice Converts the asset amount to its equivalent ETH value.
     * @param asset The address of the asset token.
     * @param amount The amount of the asset to convert.
     * @return ethValue The equivalent ETH value of the input asset amount.
     * @dev This function is mocked for testing and should not be used for accurate pricing.
     */
    function assetToEth(address asset, uint amount) public override view returns (uint ethValue) {
        if (asset == WETH) {
            return amount;
        }

        address uniswapPair = uniswapFactory.getPair(asset, WETH);
        require(uniswapPair != address(0), "Unit Protocol: UNISWAP_PAIR_DOES_NOT_EXIST");

        // token reserve of {Token}/WETH pool
        uint tokenReserve = ERC20Like(asset).balanceOf(uniswapPair);

        // revert if there is no liquidity
        require(tokenReserve != 0, "Unit Protocol: UNISWAP_EMPTY_POOL");

        // WETH reserve of {Token}/WETH pool
        uint wethReserve = ERC20Like(WETH).balanceOf(uniswapPair);

        return amount.mul(wethReserve).mul(Q112).div(tokenReserve);
    }

    /**
     * @notice Retrieves the ETH/USD price from Chainlink, see for more info: https://feeds.chain.link/eth-usd
     * @param ethAmount The amount of Ether to convert.
     * @return usdValue The USD value of the input Ether amount.
     * @dev Returns the price of the given amount of Ether in USD with 0 decimals.
     */
    function ethToUsd(uint ethAmount) public override view returns (uint usdValue) {
        require(ethUsdChainlinkAggregator.latestTimestamp() > block.timestamp - 6 hours, "Unit Protocol: OUTDATED_CHAINLINK_PRICE");
        uint ethUsdPrice = uint(ethUsdChainlinkAggregator.latestAnswer());
        return ethAmount.mul(ethUsdPrice).div(ETH_USD_DENOMINATOR);
    }
}