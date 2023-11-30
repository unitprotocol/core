// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma abicoder v2;

import "../oracles/ChainlinkedKeydonixOracleMainAssetAbstract.sol";
import "../helpers/ERC20Like.sol";
import "../helpers/SafeMath.sol";
import "../interfaces/IAggregator.sol";
import "../helpers/IUniswapV2Factory.sol";

/**
 * @title KeydonixOracleMainAsset_Mock
 * @dev Mock contract for calculating the USD price of desired tokens for testing purposes.
 */
contract KeydonixOracleMainAsset_Mock is ChainlinkedKeydonixOracleMainAssetAbstract {
    using SafeMath for uint;

    uint public constant ETH_USD_DENOMINATOR = 100000000;

    IAggregator public immutable ethUsdChainlinkAggregator;

    IUniswapV2Factory public immutable uniswapFactory;

    /**
     * @dev Constructs the KeydonixOracleMainAsset_Mock contract.
     * @param uniFactory The address of the UniswapV2Factory contract.
     * @param weth The address of the WETH token contract.
     * @param chainlinkAggregator The address of the Chainlink aggregator contract for ETH/USD price feed.
     */
    constructor(
        IUniswapV2Factory uniFactory,
        address weth,
        IAggregator chainlinkAggregator
    )
    {
        require(address(uniFactory) != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(weth != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(address(chainlinkAggregator) != address(0), "Unit Protocol: ZERO_ADDRESS");

        uniswapFactory = uniFactory;
        WETH = weth;
        ethUsdChainlinkAggregator = chainlinkAggregator;
    }

    /**
     * @notice Mock implementation to get the USD price of an asset.
     * @param asset The address of the asset token contract.
     * @param amount The amount of the asset tokens.
     * @param proofData The proof data struct (not used in mock).
     * @return The price of the given amount of asset tokens in USD.
     */
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

        return ethToUsd(assetToEth(asset, amount, proofData).div(tokenReserve));
    }

    /**
     * @notice Mock implementation to get the ETH price of an asset.
     * @param asset The address of the asset token contract.
     * @param amount The amount of the asset tokens.
     * @param proofData The proof data struct (not used in mock).
     * @return The price of the given amount of asset tokens in ETH.
     */
    function assetToEth(address asset, uint amount, ProofDataStruct memory proofData) public override view returns (uint) {

        address uniswapPair = uniswapFactory.getPair(asset, WETH);
        require(uniswapPair != address(0), "Unit Protocol: UNISWAP_PAIR_DOES_NOT_EXIST");

        proofData; // This is to silence the unused variable warning without changing the function signature.

        // WETH reserve of {Token}/WETH pool
        uint wethReserve = ERC20Like(WETH).balanceOf(uniswapPair);

        return amount.mul(wethReserve).mul(Q112);
    }

    /**
     * @notice Retrieves the price of ETH in USD from the Chainlink aggregator.
     * @param ethAmount The amount of ETH to convert to USD.
     * @return The price of the given amount of ETH in USD.
     */
    function ethToUsd(uint ethAmount) public override view returns (uint) {
        require(ethUsdChainlinkAggregator.latestTimestamp() > block.timestamp - 6 hours, "Unit Protocol: OUTDATED_CHAINLINK_PRICE");
        uint ethUsdPrice = uint(ethUsdChainlinkAggregator.latestAnswer());
        return ethAmount.mul(ethUsdPrice).div(ETH_USD_DENOMINATOR);
    }
}