// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "./VaultManagerKeep3rMainAssetBase.sol";


/**
 * @title VaultManagerKeep3rUniswapMainAsset
 **/
contract VaultManagerKeep3rUniswapMainAsset is VaultManagerKeep3rMainAssetBase {

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _keep3rOracleMainAsset The address of Keep3r-based Oracle for main asset
     **/
    constructor(address _vaultManagerParameters, address _keep3rOracleMainAsset)
    public
    VaultManagerKeep3rMainAssetBase(_vaultManagerParameters, _keep3rOracleMainAsset, 3)
    {}
}
