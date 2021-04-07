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


/**
 * @title OraclePoolToken
 * @dev Calculates the USD price of Uniswap LP tokens
 **/
contract OraclePoolToken is IOracleUsd {
    using SafeMath for uint;

    IOracleRegistry public immutable oracleRegistry;

    address public immutable WETH;

    uint public immutable Q112 = 2 ** 112;

    constructor(address _oracleRegistry) public {
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

        uint usdValue_q112 = IOracleUsd(oracle).assetToUsd(underlyingAsset, 1);
        // average price of 1 token unit in ETH
        uint eAvg = IOracleEth(oracleRegistry.oracleByAsset(WETH)).usdToEth(usdValue_q112);


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
            // flashloan buying WETH
            uint sqrtd = ePool.mul((ePool).mul(9).add(
                aPool.mul(3988000).mul(eAvg).div(Q112)
            ));
            uint eChange = sqrt(sqrtd).sub(ePool.mul(1997)).div(2000);
            ePoolCalc = ePool.add(eChange);
        } else {
            // flashloan selling WETH
            uint a = aPool.mul(eAvg);
            uint b = a.mul(9).div(Q112);
            uint c = ePool.mul(3988000);
            uint sqRoot = sqrt(a.div(Q112).mul(b.add(c)));
            uint d = a.mul(3).div(Q112);
            uint eChange = ePool.sub(d.add(sqRoot).div(2000));
            ePoolCalc = ePool.sub(eChange);
        }

        uint num = ePoolCalc.mul(2).mul(amount);
        uint priceInEth;
        if (num > Q112) {
            priceInEth = num.div(pair.totalSupply()).mul(Q112);
        } else {
            priceInEth = num.mul(Q112).div(pair.totalSupply());
        }

        return IOracleEth(oracleRegistry.oracleByAsset(WETH)).ethToUsd(priceInEth);
    }

    function sqrt(uint x) internal pure returns (uint y) {
        if (x > 3) {
            uint z = x / 2 + 1;
            y = x;
            while (z < y) {
                y = z;
                z = (x / z + z) / 2;
            }
        } else if (x != 0) {
            y = 1;
        }
    }
}
