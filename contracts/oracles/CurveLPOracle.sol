// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./OracleSimple.sol";
import "../helpers/ERC20Like.sol";
import "./OracleRegistry.sol";

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
contract CurveLPOracle is OracleSimple {

    uint public constant Q112 = 2 ** 112;
    uint public constant PRECISION = 1e18;

    // CurveProvider contract
    CurveProvider public immutable curveProvider;
    // ChainlinkedOracle contract
    ChainlinkedOracleSimple public immutable chainlinkedOracle;

    /**
     * @param _curveProvider The address of the Curve Provider. Mainnet: 0x0000000022D53366457F9d5E68Ec105046FC4383
     * @param _chainlinkedOracle The address of the Chainlinked Oracle
     **/
    constructor(address _curveProvider, address _chainlinkedOracle) {
        require(_curveProvider != address(0) && _chainlinkedOracle != address(0), "Unit Protocol: ZERO_ADDRESS");
        curveProvider = CurveProvider(_curveProvider);
        chainlinkedOracle = ChainlinkedOracleSimple(_chainlinkedOracle);
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

        uint minEthCoinPrice_q112;

        for (uint i = 0; i < coinsCount; i++) {
            uint ethCoinPrice_q112 = chainlinkedOracle.assetToEth(cP.coins(i), 1 ether);
            if (i == 0 || ethCoinPrice_q112 < minEthCoinPrice_q112) {
                minEthCoinPrice_q112 = ethCoinPrice_q112;
            }
        }

        uint minUsdCoinPrice_q112 = chainlinkedOracle.ethToUsd(minEthCoinPrice_q112) / 1 ether;

        uint price_q112 = cP.get_virtual_price() * minUsdCoinPrice_q112 / PRECISION;

        return amount * price_q112;
    }

}
