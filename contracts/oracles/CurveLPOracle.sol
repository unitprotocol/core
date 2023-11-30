// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleEth.sol";
import "../helpers/ERC20Like.sol";
import "../helpers/SafeMath.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/ICurveProvider.sol";
import "../interfaces/ICurveRegistry.sol";
import "../interfaces/ICurvePool.sol";

/**
 * @title CurveLPOracle
 * @dev Oracle to quote curve LP tokens.
 */
contract CurveLPOracle is IOracleUsd {
    using SafeMath for uint;

    uint public constant Q112 = 2 ** 112;
    uint public constant PRECISION = 1e18;

    // CurveProvider contract
    ICurveProvider public immutable curveProvider;
    // ChainlinkedOracle contract
    IOracleRegistry public immutable oracleRegistry;

    /**
     * @dev Constructs the CurveLPOracle contract.
     * @param _curveProvider The address of the Curve Provider.
     * @param _oracleRegistry The address of the OracleRegistry contract.
     */
    constructor(address _curveProvider, address _oracleRegistry) {
        require(_curveProvider != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        curveProvider = ICurveProvider(_curveProvider);
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    /**
     * @notice Converts the amount of the asset into the equivalent USD value.
     * @dev Returns the Q112-encoded value of the asset in USD.
     * @param asset The address of the LP token to be quoted.
     * @param amount The amount of the LP token.
     * @return The USD value of the input amount, Q112-encoded.
     * @throws "Unit Protocol: ZERO_ADDRESS" if the Curve Provider or OracleRegistry is a zero address.
     * @throws "Unit Protocol: NOT_A_CURVE_LP" if the provided asset is not a Curve LP token.
     * @throws "Unit Protocol: INCORRECT_DECIMALS" if the LP token does not have 18 decimals.
     * @throws "Unit Protocol: CURVE_INCORRECT_COINS_COUNT" if the Curve pool does not have any coins.
     * @throws "Unit Protocol: ORACLE_NOT_FOUND" if an oracle for a coin is not found.
     */
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        ICurveRegistry cR = ICurveRegistry(curveProvider.get_registry());
        ICurvePool cP = ICurvePool(cR.get_pool_from_lp_token(asset));
        require(address(cP) != address(0), "Unit Protocol: NOT_A_CURVE_LP");
        require(ERC20Like(asset).decimals() == uint8(18), "Unit Protocol: INCORRECT_DECIMALS");

        uint coinsCount = cR.get_n_coins(address(cP))[0];
        require(coinsCount != 0, "Unit Protocol: CURVE_INCORRECT_COINS_COUNT");

        uint minCoinPrice_q112;

        for (uint i = 0; i < coinsCount; i++) {
            address _coin = cP.coins(i);
            address oracle = oracleRegistry.oracleByAsset(_coin);
            require(oracle != address(0), "Unit Protocol: ORACLE_NOT_FOUND");
            uint _coinPrice_q112 = IOracleUsd(oracle).assetToUsd(_coin, 10 ** ERC20Like(_coin).decimals()) / 1 ether;
            if (i == 0 || _coinPrice_q112 < minCoinPrice_q112) {
                minCoinPrice_q112 = _coinPrice_q112;
            }
        }

        uint price_q112 = cP.get_virtual_price().mul(minCoinPrice_q112).div(PRECISION);

        return amount.mul(price_q112);
    }

}