// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "../VaultParameters.sol";


/**
 * @title VaultManagerParameters
 **/
contract VaultManagerParameters is Auth {

    // determines the minimum percentage of COL token part in collateral, 0 decimals
    mapping(address => uint) public minColPercent;

    // determines the maximum percentage of COL token part in collateral, 0 decimals
    mapping(address => uint) public maxColPercent;

    // map token to initial collateralization ratio; 0 decimals
    mapping(address => uint) public initialCollateralRatio;

    // map token to liquidation ratio; 0 decimals
    mapping(address => uint) public liquidationRatio;

    // map token to liquidation discount; 3 decimals
    mapping(address => uint) public liquidationDiscount;

    // map token to devaluation period in blocks
    mapping(address => uint) public devaluationPeriod;

    constructor(address _vaultParameters) public Auth(_vaultParameters) {}

    /**
     * @notice Only manager is able to call this function
     * @dev Sets ability to use token as the main collateral
     * @param asset The address of the main collateral token
     * @param stabilityFeeValue The percentage of the year stability fee (3 decimals)
     * @param liquidationFeeValue The liquidation fee percentage (0 decimals)
     * @param initialCollateralRatioValue The initial collateralization ratio
     * @param liquidationRatioValue The liquidation ratio
     * @param liquidationDiscountValue The liquidation discount (3 decimals)
     * @param devaluationPeriodValue The devaluation period in blocks
     * @param usdpLimit The USDP token issue limit
     * @param oracles The enabled oracles type IDs
     * @param minColP The min percentage of COL value in position (0 decimals)
     * @param maxColP The max percentage of COL value in position (0 decimals)
     **/
    function setCollateral(
        address asset,
        uint stabilityFeeValue,
        uint liquidationFeeValue,
        uint initialCollateralRatioValue,
        uint liquidationRatioValue,
        uint liquidationDiscountValue,
        uint devaluationPeriodValue,
        uint usdpLimit,
        uint[] calldata oracles,
        uint minColP,
        uint maxColP
    ) external onlyManager {
        vaultParameters.setCollateral(asset, stabilityFeeValue, liquidationFeeValue, usdpLimit, oracles);
        setInitialCollateralRatio(asset, initialCollateralRatioValue);
        setLiquidationRatio(asset, liquidationRatioValue);
        setDevaluationPeriod(asset, devaluationPeriodValue);
        setLiquidationDiscount(asset, liquidationDiscountValue);
        setColPartRange(asset, minColP, maxColP);
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the initial collateral ratio
     * @param asset The address of the main collateral token
     * @param newValue The collateralization ratio (0 decimals)
     **/
    function setInitialCollateralRatio(address asset, uint newValue) public onlyManager {
        require(newValue != 0 && newValue <= 100, "Unit Protocol: INCORRECT_COLLATERALIZATION_VALUE");
        initialCollateralRatio[asset] = newValue;
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the liquidation ratio
     * @param asset The address of the main collateral token
     * @param newValue The liquidation ratio (0 decimals)
     **/
    function setLiquidationRatio(address asset, uint newValue) public onlyManager {
        require(newValue != 0 && newValue >= initialCollateralRatio[asset], "Unit Protocol: INCORRECT_COLLATERALIZATION_VALUE");
        liquidationRatio[asset] = newValue;
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the liquidation discount
     * @param asset The address of the main collateral token
     * @param newValue The liquidation discount (3 decimals)
     **/
    function setLiquidationDiscount(address asset, uint newValue) public onlyManager {
        require(newValue < 1e5, "Unit Protocol: INCORRECT_DISCOUNT_VALUE");
        liquidationDiscount[asset] = newValue;
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the devaluation period of collateral after liquidation
     * @param asset The address of the main collateral token
     * @param newValue The devaluation period in blocks
     **/
    function setDevaluationPeriod(address asset, uint newValue) public onlyManager {
        require(newValue != 0, "Unit Protocol: INCORRECT_DEVALUATION_VALUE");
        devaluationPeriod[asset] = newValue;
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the percentage range of the COL token part for specific collateral token
     * @param asset The address of the main collateral token
     * @param min The min percentage (0 decimals)
     * @param max The max percentage (0 decimals)
     **/
    function setColPartRange(address asset, uint min, uint max) public onlyManager {
        require(max <= 100 && min <= max, "Unit Protocol: WRONG_RANGE");
        minColPercent[asset] = min;
        maxColPercent[asset] = max;
    }
}
