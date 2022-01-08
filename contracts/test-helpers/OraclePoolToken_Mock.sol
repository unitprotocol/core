// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../helpers/SafeMath.sol";
import "../helpers/IUniswapV2PairFull.sol";
import "../interfaces/IOracleEth.sol";
import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IToken.sol";

/**
 * @title OraclePoolToken_Mock
 * @dev as OraclePoolToken but without flashloan resistance for test purposes
 **/
contract OraclePoolToken_Mock is IOracleUsd {
    using SafeMath for uint;

    IOracleRegistry public immutable oracleRegistry;

    address public immutable WETH;

    uint public immutable Q112 = 2 ** 112;

    constructor(address _oracleRegistry) {
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        WETH = IOracleRegistry(_oracleRegistry).WETH();
    }

    /**
     * @notice Flashloan-resistant logic to determine USD price of Uniswap LP tokens
     * @notice Pair must be registered at Chainlink
     * @param asset The LP token address
     * @param amount Amount of asset
     * @return Q112 encoded price of asset in USD
     **/
    function assetToUsd(
        address asset,
        uint amount
    )
        public
        override
        view
        returns (uint)
    {
        IUniswapV2PairFull pair = IUniswapV2PairFull(asset);
        address underlyingAsset;
        if (pair.token0() == WETH) {
            underlyingAsset = pair.token1();
        } else if (pair.token1() == WETH) {
            underlyingAsset = pair.token0();
        } else {
            revert("Unit Protocol: NOT_REGISTERED_PAIR");
        }

        address oracle = oracleRegistry.oracleByAsset(underlyingAsset);
        require(oracle != address(0), "Unit Protocol: ORACLE_NOT_FOUND");

        uint eAvg;

        { // fix stack too deep
          uint assetPrecision = 10 ** IToken(underlyingAsset).decimals();

          uint usdValue_q112 = IOracleUsd(oracle).assetToUsd(underlyingAsset, assetPrecision) / assetPrecision;
          // average price of 1 token unit in ETH
          eAvg = IOracleEth(oracleRegistry.oracleByAsset(WETH)).usdToEth(usdValue_q112);
        }

        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();
        uint aPool; // current asset pool
        uint ePool; // current WETH pool
        if (pair.token0() == underlyingAsset) {
            aPool = uint(_reserve0);
            ePool = uint(_reserve1);
        } else {
            aPool = uint(_reserve1);
            ePool = uint(_reserve0);
        }

        uint ePoolCalc; // calculated WETH pool

        ePoolCalc = ePool;

        uint num = ePoolCalc.mul(2).mul(amount);
        uint priceInEth;
        if (num > Q112) {
            priceInEth = num.div(pair.totalSupply()).mul(Q112);
        } else {
            priceInEth = num.mul(Q112).div(pair.totalSupply());
        }

        return IOracleEth(oracleRegistry.oracleByAsset(WETH)).ethToUsd(priceInEth);
    }

}
