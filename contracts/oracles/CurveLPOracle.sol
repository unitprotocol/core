// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleEth.sol";
import "../helpers/ERC20Like.sol";
import "./OracleRegistry.sol";
import "../interfaces/IOracleRegistry.sol";

interface CurveProvider {
    function get_registry() external view returns (address);
}

interface CurveRegistry {
    function get_pool_from_lp_token(address) external view returns (address);
    function get_n_coins(address) external view returns (uint[2] memory);
}

interface CurvePool {
    function get_virtual_price() external view returns (uint);
    function coins(uint) external view returns (address);
}

/**
 * @title CurveLPOracle
 * @dev Oracle to quote curve LP tokens
 **/
contract CurveLPOracle is IOracleUsd {

    uint public constant Q112 = 2 ** 112;
    uint public constant PRECISION = 1e18;

    // CurveProvider contract
    CurveProvider public immutable curveProvider;
    // ChainlinkedOracle contract
    IOracleRegistry public immutable oracleRegistry;

    /**
     * @param _curveProvider The address of the Curve Provider. Mainnet: 0x0000000022D53366457F9d5E68Ec105046FC4383
     * @param _oracleRegistry The address of the OracleRegistry contract
     **/
    constructor(address _curveProvider, address _oracleRegistry) {
        require(_curveProvider != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        curveProvider = CurveProvider(_curveProvider);
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        CurveRegistry cR = CurveRegistry(curveProvider.get_registry());
        CurvePool cP = CurvePool(cR.get_pool_from_lp_token(asset));
        require(address(cP) != address(0), "Unit Protocol: NOT_A_CURVE_LP");
        require(ERC20Like(asset).decimals() == uint8(18), "Unit Protocol: INCORRECT_DECIMALS");

        uint coinsCount = cR.get_n_coins(address(cP))[0];
        require(coinsCount != 0, "Unit Protocol: CURVE_INCORRECT_COINS_COUNT");

        uint minCoinPrice_q112;

        for (uint i = 0; i < coinsCount; i++) {
            address _coin = cP.coins(i);
            uint _coinPrice_q112 = IOracleUsd(oracleRegistry.oracleByAsset(_coin)).assetToUsd(_coin, 1);
            if (i == 0 || _coinPrice_q112 < minCoinPrice_q112) {
                minCoinPrice_q112 = _coinPrice_q112;
            }
        }

        uint price_q112 = cP.get_virtual_price() * minCoinPrice_q112 / PRECISION;

        return amount * price_q112;
    }

}
