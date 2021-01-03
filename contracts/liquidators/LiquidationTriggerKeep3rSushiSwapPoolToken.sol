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
 * @title LiquidationTriggerKeep3rSushiSwapPoolToken
 * @dev Manages liquidation process triggering of pool tokens based positions
 **/
contract LiquidationTriggerKeep3rSushiSwapPoolToken is LiquidationTriggerSimple, ReentrancyGuard {
    using SafeMath for uint;

    // uniswap-based oracle contract
    OracleSimple public immutable keep3rOraclePoolToken;

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _keep3rOraclePoolToken The address of Keep3r-based Oracle for pool tokens
     **/
    constructor(
        address _vaultManagerParameters,
        address _keep3rOraclePoolToken
    )
    public
    LiquidationTriggerSimple(_vaultManagerParameters, 8)
    {
        keep3rOraclePoolToken = OracleSimple(_keep3rOraclePoolToken);
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function triggerLiquidation(address asset, address user) public override nonReentrant{
        // USD value of the main collateral
        uint mainUsdValue_q112 = keep3rOraclePoolToken.assetToUsd(asset, vault.collaterals(asset, user));

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
