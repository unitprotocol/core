// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../oracle/ChainlinkedUniswapOracle.sol";
import "../helpers/ERC20Like.sol";

/**
 * @title UniswapOracle
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Calculates the USD price of desired tokens
 **/
contract ChainlinkedUniswapOracleMock {
    using SafeMath for uint;

    uint8 public MIN_BLOCKS_BACK = uint8(100);

    uint8 public constant MAX_BLOCKS_BACK = uint8(255);

    uint public constant ETH_USD_DENOMINATOR = 100000000;

    uint public constant Q112 = 2**112;

    AggregatorInterface public ethUsdChainlinkAggregator;

    IUniswapV2Factory public uniswapFactory;

    address public WETH;

    constructor(
        IUniswapV2Factory uniFactory,
        address weth,
        AggregatorInterface chainlinkAggregator
    )
        public
    {
        require(address(uniFactory) != address(0), "USDP: ZERO_ADDRESS");
        require(weth != address(0), "USDP: ZERO_ADDRESS");
        require(address(chainlinkAggregator) != address(0), "USDP: ZERO_ADDRESS");

        uniswapFactory = uniFactory;
        WETH = weth;
        ethUsdChainlinkAggregator = chainlinkAggregator;
    }

    // override to old mechanics
    // only for tests
    function assetToUsd(address asset, uint amount, USDPLib.ProofData memory proofData) public view returns (uint) {
        address uniswapPair = uniswapFactory.getPair(asset, WETH);
        require(uniswapPair != address(0), "USDP: UNISWAP_PAIR_DOES_NOT_EXIST");

        proofData;

        // token reserve of {Token}/WETH pool
        uint tokenReserve = ERC20Like(asset).balanceOf(uniswapPair);

        // revert if there is no liquidity
        require(tokenReserve > 0, "USDP: UNISWAP_EMPTY_POOL");

        // WETH reserve of {Token}/WETH pool
        uint wethReserve = ERC20Like(WETH).balanceOf(uniswapPair);

        uint wethResult = amount.mul(wethReserve);

        return ethToUsd(wethResult).div(tokenReserve);
    }

    /**
     * @notice ETH/USD price feed from Chainlink see for more info: https://feeds.chain.link/eth-usd
     * returns Price of given amount of Ether in USD (0 decimals)
     **/
    function ethToUsd(uint ethAmount) public view returns (uint) {
        require(ethUsdChainlinkAggregator.latestTimestamp() > now - 6 hours, "USDP: OUTDATED_CHAINLINK_PRICE");
        uint ethUsdPrice = uint(ethUsdChainlinkAggregator.latestAnswer());
        return ethAmount.mul(ethUsdPrice).div(ETH_USD_DENOMINATOR);
    }
}
