// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "./VaultManagerKeep3rPoolTokenBase.sol";


/**
 * @title VaultManagerKeep3rUniswapPoolToken
 **/
contract VaultManagerKeep3rUniswapPoolToken is VaultManagerKeep3rPoolTokenBase {

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _keep3rPoolToken The address of Keep3r-based Oracle for pool tokens
     **/
    constructor(address _vaultManagerParameters, address _keep3rPoolToken)
    public
    VaultManagerKeep3rPoolTokenBase(_vaultManagerParameters, _keep3rPoolToken, 4)
    {}
}
