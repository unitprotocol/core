// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../helpers/ERC20Like.sol";
import "../helpers/ReentrancyGuard.sol";
import "./LiquidationTriggerBase.sol";
import "../oracles/OracleSimple.sol";


/**
 * @title LiquidationTriggerSimple
 * @dev Manages liquidation triggering
 **/
contract LiquidationTriggerSimple is LiquidationTriggerBase, ReentrancyGuard {
    using SafeMath for uint;

    OracleSimple public immutable oracle;

    uint public constant Q112 = 2**112;

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _oracle The address of simple oracle
     * @param _oracleType The id of the oracle type
     **/
    constructor(
        address _vaultManagerParameters,
        address _oracle,
        uint _oracleType
    )
    public
    LiquidationTriggerBase(_vaultManagerParameters, _oracleType)
    {
        oracle = OracleSimple(_oracle);
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param mainUsdValue_q112 Q112-encoded USD value of the main collateral
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address user,
        uint mainUsdValue_q112
    ) public override view returns (bool){
        uint debt = vault.getTotalDebt(asset, user);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        require(vault.oracleType(asset, user) == oracleType, "Unit Protocol: INCORRECT_ORACLE_TYPE");

        return UR(mainUsdValue_q112, debt) >= vaultManagerParameters.liquidationRatio(asset);
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function triggerLiquidation(address asset, address user) public override nonReentrant {
        // USD value of the main collateral
        uint mainUsdValue_q112 = oracle.assetToUsd(asset, vault.collaterals(asset, user));

        // reverts if a position is not liquidatable
        require(isLiquidatablePosition(asset, user, mainUsdValue_q112), "Unit Protocol: SAFE_POSITION");

        uint liquidationDiscount_q112 = mainUsdValue_q112.mul(
            vaultManagerParameters.liquidationDiscount(asset)
        ).div(DENOMINATOR_1E5);

        uint initialLiquidationPrice = mainUsdValue_q112.sub(liquidationDiscount_q112).div(Q112);

        // sends liquidation command to the Vault
        vault.triggerLiquidation(asset, user, initialLiquidationPrice);

        // fire an liquidation event
        emit LiquidationTriggered(asset, user);
    }

    /**
     * @dev Calculates position's utilization ratio
     * @param mainUsdValue USD value of main collateral, q112 format
     * @param debt USDP borrowed
     * @return utilization ratio of a position
     **/
    function UR(uint mainUsdValue, uint debt) public override pure returns (uint) {
        return debt.mul(100).mul(Q112).div(mainUsdValue);
    }
}
