// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../oracles/ChainlinkedKeydonixOracleMainAssetAbstract.sol";
import "../helpers/ERC20Like.sol";
import "../helpers/SafeMath.sol";
import "../helpers/AggregatorInterface.sol";
import "../helpers/IUniswapV2Factory.sol";

/**
 * @title KeydonixOracleMainAsset_Mock
 * @dev Calculates the USD price of desired tokens
 **/
contract KeydonixOracleMainAsset_Mock is ChainlinkedKeydonixOracleMainAssetAbstract {
    using SafeMath for uint;

    uint public constant ETH_USD_DENOMINATOR = 100000000;

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
    function assetToUsd(address asset, uint amount, ProofDataStruct memory proofData) public override view returns (uint) {

        if (asset == WETH) {
            return ethToUsd(amount);
        }

        address uniswapPair = uniswapFactory.getPair(asset, WETH);
        require(uniswapPair != address(0), "Unit Protocol: UNISWAP_PAIR_DOES_NOT_EXIST");

        // token reserve of {Token}/WETH pool
        uint tokenReserve = ERC20Like(asset).balanceOf(uniswapPair);

        // revert if there is no liquidity
        require(tokenReserve != 0, "Unit Protocol: UNISWAP_EMPTY_POOL");

        return ethToUsd(assetToEth(asset, amount, proofData)).div(tokenReserve);
    }

    // override with mock; only for tests
    function assetToEth(address asset, uint amount, ProofDataStruct memory proofData) public override view returns (uint) {

        address uniswapPair = uniswapFactory.getPair(asset, WETH);
        require(uniswapPair != address(0), "Unit Protocol: UNISWAP_PAIR_DOES_NOT_EXIST");

        proofData;

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
