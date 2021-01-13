// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../helpers/ERC20Like.sol";
import "../helpers/ReentrancyGuard.sol";
import "./LiquidationTriggerSimple.sol";
import "../oracles/OracleSimple.sol";


/**
 * @title LiquidationTriggerChainlinkMainAsset
 * @dev Manages liquidation process triggering of main asset-based positions
 **/
contract LiquidationTriggerChainlinkMainAsset is LiquidationTriggerSimple, ReentrancyGuard {
    using SafeMath for uint;

    // uniswap-based oracle contract
    ChainlinkedOracleSimple public immutable chainlinkedOracleMainAsset;

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _chainlinkedOracleMainAsset The address of Chainlink-based oracle wrapper for main assets
     **/
    constructor(
        address _vaultManagerParameters,
        address _chainlinkedOracleMainAsset
    )
    public
    LiquidationTriggerSimple(_vaultManagerParameters, 5)
    {
        chainlinkedOracleMainAsset = ChainlinkedOracleSimple(_chainlinkedOracleMainAsset);
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function triggerLiquidation(address asset, address user) public override nonReentrant {
        // USD value of the main collateral
        uint mainUsdValue = chainlinkedOracleMainAsset.assetToUsd(asset, vault.collaterals(asset, user));

        // reverts if a position is not liquidatable
        require(isLiquidatablePosition(asset, user, mainUsdValue), "Unit Protocol: SAFE_POSITION");

        uint liquidationDiscount = mainUsdValue.mul(
            vaultManagerParameters.liquidationDiscount(asset)
        ).div(DENOMINATOR_1E5);

        uint initialLiquidationPrice = mainUsdValue.sub(liquidationDiscount);

        // sends liquidation command to the Vault
        vault.triggerLiquidation(asset, user, initialLiquidationPrice);

        // fire an liquidation event
        emit LiquidationTriggered(asset, user);
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param mainUsdValue USD value of the main collateral
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address user,
        uint mainUsdValue
    ) public override view returns (bool) {
        uint debt = vault.getTotalDebt(asset, user);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        require(vault.oracleType(asset, user) == oracleType, "Unit Protocol: INCORRECT_ORACLE_TYPE");

        return UR(mainUsdValue, debt) >= vaultManagerParameters.liquidationRatio(asset);
    }

    /**
     * @dev Calculates position's utilization ratio
     * @param mainUsdValue USD value of main collateral
     * @param debt USDP borrowed
     * @return utilization ratio of a position
     **/
    function UR(uint mainUsdValue, uint debt) public override pure returns (uint) {
        return debt.mul(100).div(mainUsdValue);
    }
}
