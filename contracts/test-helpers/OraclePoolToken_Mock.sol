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

/* @title Mock Oracle for Uniswap LP tokens to test USD price determination
 * @dev Extends IOracleUsd to provide USD price of Uniswap LP tokens for testing purposes
 */
contract OraclePoolToken_Mock is IOracleUsd {
    using SafeMath for uint;

    /* @notice Reference to the Oracle Registry contract */
    IOracleRegistry public immutable oracleRegistry;

    /* @notice Address of the Wrapped Ether (WETH) contract */
    address public immutable WETH;

    /* @notice Constant used for Q112 encoding (2**112) */
    uint public immutable Q112 = 2 ** 112;

    /* @notice Constructor to set the Oracle Registry and WETH addresses
     * @param _oracleRegistry The address of the Oracle Registry contract
     */
    constructor(address _oracleRegistry) {
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        WETH = IOracleRegistry(_oracleRegistry).WETH();
    }

    /* @notice Returns the USD price of an asset
     * @dev Calculates the price using Uniswap LP tokens and registered oracles
     * @param asset The address of the LP token
     * @param amount The amount of the LP token
     * @return The price of the asset in USD, encoded in Q112 format
     * @dev Throws if the pair is not registered or if the oracle is not found
     */
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