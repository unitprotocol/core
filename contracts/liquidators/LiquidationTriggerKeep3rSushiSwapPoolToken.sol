// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "../helpers/ERC20Like.sol";
import "./LiquidationTriggerSimple.sol";
import "../oracles/OracleSimple.sol";


/**
 * @title LiquidationTriggerKeep3rSushiSwapPoolToken
 * @dev Manages liquidation process triggering of pool tokens based positions
 **/
contract LiquidationTriggerKeep3rSushiSwapPoolToken is LiquidationTriggerSimple {


    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _keep3rOraclePoolToken The address of Keep3r-based Oracle for pool tokens
     **/
    constructor(
        address _vaultManagerParameters,
        address _keep3rOraclePoolToken
    )
    public
    LiquidationTriggerSimple(_vaultManagerParameters, _keep3rOraclePoolToken, 8)
    {}
}
