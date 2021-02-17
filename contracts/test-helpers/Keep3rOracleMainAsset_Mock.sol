// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../helpers/ERC20Like.sol";
import "../helpers/SafeMath.sol";
import "../helpers/AggregatorInterface.sol";
import "../helpers/IUniswapV2Factory.sol";
import "../oracles/OracleSimple.sol";

/**
 * @title Keep3rOracleMainAsset_Mock
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Calculates the USD price of desired tokens
 **/
contract Keep3rOracleMainAsset_Mock is ChainlinkedOracleSimple {
    using SafeMath for uint;

    uint public immutable Q112 = 2 ** 112;
    uint public immutable ETH_USD_DENOMINATOR = 100000000;

    AggregatorInterface public immutable ethUsdChainlinkAggregator;

    IUniswapV2Factory public immutable uniswapFactory;

    constructor(
        IUniswapV2Factory uniFactory,
        address weth,
        AggregatorInterface chainlinkAggregator
    )
        public
    {
        require(address(uniFactory) != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(weth != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(address(chainlinkAggregator) != address(0), "Unit Protocol: ZERO_ADDRESS");

        uniswapFactory = uniFactory;
        WETH = weth;
        ethUsdChainlinkAggregator = chainlinkAggregator;
    }

    // override with mock; only for tests
    function assetToUsd(address asset, uint amount) public override view returns (uint) {

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

    function assetToEth(address asset, uint amount) public override view returns (uint) {
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

        return amount.mul(wethReserve).mul(Q112);
    }

    /**
     * @notice ETH/USD price feed from Chainlink, see for more info: https://feeds.chain.link/eth-usd
     * returns Price of given amount of Ether in USD (0 decimals)
     **/
    function ethToUsd(uint ethAmount) public override view returns (uint) {
        require(ethUsdChainlinkAggregator.latestTimestamp() > block.timestamp - 6 hours, "Unit Protocol: OUTDATED_CHAINLINK_PRICE");
        uint ethUsdPrice = uint(ethUsdChainlinkAggregator.latestAnswer());
        return ethAmount.mul(ethUsdPrice).div(ETH_USD_DENOMINATOR);
    }
}
