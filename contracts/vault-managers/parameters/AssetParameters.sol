// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/* 
 * @title AssetParameters
 * @dev Library to handle asset-specific parameters for liquidation logic.
 */
library AssetParameters {

    /* Some assets require a transfer of at least 1 unit of token
     * to update internal logic related to staking rewards in case of full liquidation.
     */
    uint8 public constant PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION = 0;

    /* Some wrapped assets that require a manual position transfer between users
     * since `transfer` doesn't do this.
     */
    uint8 public constant PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION = 1;

    /**
     * @dev Determines if an asset requires force transfer to owner on liquidation.
     * @param assetBoolParams The encoded boolean parameters for the asset.
     * @return bool True if force transfer is needed, false otherwise.
     */
    function needForceTransferAssetToOwnerOnLiquidation(uint256 assetBoolParams) internal pure returns (bool) {
        return assetBoolParams & (1 << PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION) != 0;
    }

    /**
     * @dev Determines if a wrapped asset requires a manual position transfer on liquidation.
     * @param assetBoolParams The encoded boolean parameters for the wrapped asset.
     * @return bool True if manual position transfer is needed, false otherwise.
     */
    function needForceMoveWrappedAssetPositionOnLiquidation(uint256 assetBoolParams) internal pure returns (bool) {
        return assetBoolParams & (1 << PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION) != 0;
    }
}