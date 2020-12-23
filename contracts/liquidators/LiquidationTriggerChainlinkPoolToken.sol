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
 * @title LiquidationTriggerKeep3rPoolToken
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process triggering of main asset-based positions
 **/
contract LiquidationTriggerChainlinkPoolToken is LiquidationTriggerSimple, ReentrancyGuard {
    using SafeMath for uint;

    // uniswap-based oracle contract
    OracleSimple public immutable chainlinkOraclePoolToken;

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _chainlinkOraclePoolToken The address of Chainlink-based oracle wrapper for pool tokens
     **/
    constructor(
        address _vaultManagerParameters,
        address _chainlinkOraclePoolToken
    )
    public
    LiquidationTriggerSimple(_vaultManagerParameters, 4)
    {
        chainlinkOraclePoolToken = OracleSimple(_chainlinkOraclePoolToken);
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function triggerLiquidation(address asset, address user) public override nonReentrant{
        // USD value of the main collateral
        uint mainUsdValue_q112 = chainlinkOraclePoolToken.assetToUsd(asset, vault.collaterals(asset, user));

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
}
