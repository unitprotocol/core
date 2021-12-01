// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../VaultParameters.sol";
import "../interfaces/auction/IForceMovePositionAssetStore.sol";


/**
 * @title ForceMovePositionAssetStore
 **/
contract ForceMovePositionAssetStore is Auth, IForceMovePositionAssetStore {

    /**
     * Mapping of wrapped assets that require a manual position transfer between users
     * since `transfer` doesn't do this
     */
    mapping(address => bool) public override shouldForceMovePosition;

    event ForceMovePositionAssetAdded(address indexed asset);

    constructor(address _vaultParameters, address[] memory initialAssets) Auth(_vaultParameters) {
        for (uint i = 0; i < initialAssets.length; i++) {
            add(initialAssets[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Mark asset for manual moving positions in case of liquidations
     * @param asset The address of the asset
     **/
    function add(address asset) public override onlyManager {
        require(!shouldForceMovePosition[asset], "Unit Protocol: Already exists");
        require(asset != address(0), "Unit Protocol: ZERO_ADDRESS");
        shouldForceMovePosition[asset] = true;
        emit ForceMovePositionAssetAdded(asset);
    }
}
