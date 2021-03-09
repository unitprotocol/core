// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "./OracleSimple.sol";
import "../helpers/ERC20Like.sol";
import "./OracleRegistry.sol";

interface CurveProvider {
    function get_registry() external view returns (address);
}

interface CurveRegistry {
    function get_pool_from_lp_token(address) external view returns (address);
    function get_virtual_price_from_lp_token(address) external view returns (uint);
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

    /**
     * @param _curveProvider The address of the Curve Provider. Mainnet: 0x0000000022D53366457F9d5E68Ec105046FC4383
     **/
    constructor(address _curveProvider) {
        require(_curveProvider != address(0), "Unit Protocol: ZERO_ADDRESS");
        curveProvider = CurveProvider(_curveProvider);
    }

    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        CurveRegistry cR = CurveRegistry(curveProvider.get_registry());
        require(cR.get_pool_from_lp_token(asset) != address(0), "Unit Protocol: NOT_A_CURVE_LP");

        uint price_q112 = cR.get_virtual_price_from_lp_token(asset) * Q112 / PRECISION;
        return amount * price_q112;
    }

}
