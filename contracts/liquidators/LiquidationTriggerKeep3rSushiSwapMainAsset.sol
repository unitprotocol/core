// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "../helpers/ERC20Like.sol";
import "./LiquidationTriggerKeep3rBase.sol";
import "../oracles/OracleSimple.sol";


/**
 * @title LiquidationTriggerKeep3rSushiSwapMainAsset
 * @dev Manages liquidation process triggering of main asset based positions
 **/
contract LiquidationTriggerKeep3rSushiSwapMainAsset is LiquidationTriggerKeep3rBase {


    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _keep3rOracleMainAsset The address of Keep3r-based Oracle for main assets
     **/
    constructor(
        address _vaultManagerParameters,
        address _keep3rOracleMainAsset
    )
    public
    LiquidationTriggerKeep3rBase(_vaultManagerParameters, _keep3rOracleMainAsset, 7)
    {}
}
