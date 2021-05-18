// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../VaultParameters.sol";
import "../interfaces/IForceTransferAssetStore.sol";


/**
 * @title ForceTransferAssetStore
 **/
contract ForceTransferAssetStore is Auth, IForceTransferAssetStore {

    /*
        Mapping of assets that require a transfer of at least 1 unit of token
        to update internal logic related to staking rewards in case of full liquidation
     */
    mapping(address => bool) public override shouldForceTransfer;

    event ForceTransferAssetAdded(address indexed asset);

    constructor(address _vaultParameters, address[] memory initialAssets) Auth(_vaultParameters) {
        for (uint i = 0; i < initialAssets.length; i++) {
            require(!shouldForceTransfer[initialAssets[i]], "Unit Protocol: Already exists");
            shouldForceTransfer[initialAssets[i]] = true;
            emit ForceTransferAssetAdded(initialAssets[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Mark asset as `shouldForceTransfer`
     * @param asset The address of the asset
     **/
    function add(address asset) external override onlyManager {
        require(!shouldForceTransfer[asset], "Unit Protocol: Already exists");
        require(asset != address(0), "Unit Protocol: ZERO_ADDRESS");
        shouldForceTransfer[asset] = true;
        emit ForceTransferAssetAdded(asset);
    }
}
