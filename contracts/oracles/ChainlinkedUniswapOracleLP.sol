// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./ChainlinkedUniswapOracle.sol";
import "../helpers/IUniswapV2PairFull.sol";


/**
 * @title ChainlinkedUniswapOracleLP
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Calculates the USD price of Uniswap LP tokens
 **/
contract ChainlinkedUniswapOracleLP {
    using SafeMath for uint;

    uint public constant Q112 = 2**112;

    ChainlinkedUniswapOracle public chainlinkedUniswapOracle;

    constructor(ChainlinkedUniswapOracle _chainlinkedUniswapOracle) public {
        chainlinkedUniswapOracle = _chainlinkedUniswapOracle;
    }

    /**
     * @notice This function implements flashloan-resistant logic to determine USD price of Uniswap LP tokens
     * @notice Block number of merkle proof must be in range [MIN_BLOCKS_BACK ... MAX_BLOCKS_BACK] blocks ago (see ChainlinkedUniswapOracle)
     * @notice Pair must be registered on Uniswap
     * @param asset The LP token address
     * @param amount Amount of asset
     * @return Q112 encoded price of asset in USD
     **/
    function assetToUsd(address asset, uint amount, UniswapOracle.ProofData memory proofData) public view returns (uint) {
        IUniswapV2PairFull pair = IUniswapV2PairFull(asset);
        address underlyingAsset;
        if (pair.token0() == chainlinkedUniswapOracle.WETH()) {
            underlyingAsset = pair.token1();
        } else if (pair.token1() == chainlinkedUniswapOracle.WETH()) {
            underlyingAsset = pair.token0();
        } else {
            revert("USDP: NOT_REGISTERED_PAIR");
        }

        uint eAvg = chainlinkedUniswapOracle.assetToEth(underlyingAsset, 1, proofData); // average price of 1 token in ETH

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

        uint eCurr = ePool.mul(Q112).div(aPool); // current price of 1 token in WETH
        uint ePoolCalc; // calculated WETH pool

        if (eCurr < eAvg) {
            // flashloan with buying WETH
            uint sqrtd = ePool.mul((ePool).mul(9).add(
                aPool.mul(3988000).mul(eAvg).div(Q112)
            ));
            uint eChange = sqrt(sqrtd).sub(ePool.mul(1997)).div(2000);
            ePoolCalc = ePool.add(eChange);
        } else {
            // flashloan with selling WETH
            uint a = aPool.mul(eAvg);
            uint b = a.mul(9).div(Q112);
            uint c = ePool.mul(3988000);
            uint sqRoot = sqrt(a.div(Q112).mul(b.add(c)));
            uint d = a.mul(3).div(Q112);
            uint eChange = ePool.sub(d.add(sqRoot).div(2000));
            ePoolCalc = ePool.sub(eChange);
        }

        uint num = ePoolCalc.mul(2).mul(amount).mul(Q112);
        uint priceInEth = num.div(pair.totalSupply());

        return chainlinkedUniswapOracle.ethToUsd(priceInEth);
    }


    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
