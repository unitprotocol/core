// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../oracles/KeydonixOracleAbstract.sol";
import "../vault-managers/VaultManagerParameters.sol";
import "../helpers/ReentrancyGuard.sol";


/**
 * @title LiquidationTriggerSimple
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages triggering of liquidation process
 **/
abstract contract LiquidationTriggerSimple {
    using SafeMath for uint;

    uint public constant Q112 = 2**112;
    uint public constant DENOMINATOR_1E5 = 1e5;
    uint public constant DENOMINATOR_1E2 = 1e2;

    // vault manager parameters contract
    VaultManagerParameters public immutable vaultManagerParameters;

    uint public immutable oracleType;

    // Vault contract
    Vault public immutable vault;

    /**
     * @dev Trigger when liquidations are initiated
    **/
    event LiquidationTriggered(address indexed token, address indexed user);

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _oracleType The id of the oracle type
     **/
    constructor(address _vaultManagerParameters, uint _oracleType) internal {
        vaultManagerParameters = VaultManagerParameters(_vaultManagerParameters);
        vault = Vault(VaultManagerParameters(_vaultManagerParameters).vaultParameters().vault());
        oracleType = _oracleType;
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function triggerLiquidation(address asset, address user) external virtual {}

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param mainUsdValue_q112 Q112-encoded USD value of the main collateral
     * @param colUsdValue_q112 Q112-encoded USD value of the COL amount
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address user,
        uint mainUsdValue_q112,
        uint colUsdValue_q112
    ) public view returns (bool){
        uint debt = vault.getTotalDebt(asset, user);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        require(vault.oracleType(asset, user) == oracleType, "Unit Protocol: INCORRECT_ORACLE_TYPE");

        return UR(mainUsdValue_q112, colUsdValue_q112, debt) >= LR(asset, mainUsdValue_q112, colUsdValue_q112);
    }

    /**
     * @dev Calculates position's utilization ratio
     * @param mainUsdValue USD value of main collateral
     * @param colUsdValue USD value of COL amount
     * @param debt USDP borrowed
     * @return utilization ratio of a position
     **/
    function UR(uint mainUsdValue, uint colUsdValue, uint debt) public view returns (uint) {
        return debt.mul(100).mul(Q112).div(mainUsdValue.add(colUsdValue));
    }

    /**
     * @dev Calculates position's liquidation ratio based on collateral proportion
     * @param asset The address of the main collateral token of a position
     * @param mainUsdValue USD value of main collateral in position
     * @param colUsdValue USD value of COL amount in position
     * @return liquidation ratio of a position
     **/
    function LR(address asset, uint mainUsdValue, uint colUsdValue) public view returns(uint) {
        uint lrMain = vaultManagerParameters.liquidationRatio(asset);
        uint lrCol = vaultManagerParameters.liquidationRatio(vault.col());

        return lrMain.mul(mainUsdValue).add(lrCol.mul(colUsdValue)).div(mainUsdValue.add(colUsdValue));
    }
}
