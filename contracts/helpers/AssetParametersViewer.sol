// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

pragma experimental ABIEncoderV2;

import "../interfaces/IVaultParameters.sol";
import "../interfaces/IVaultManagerParameters.sol";
import "../interfaces/IForceTransferAssetStore.sol";


/**
 * @notice Views collaterals in one request to save node requests and speed up dapps.
 *
 * @dev It makes no sense to clog a node with hundreds of RPC requests and slow a client app/dapp. Since usually
 *      a huge amount of gas is available to node static calls, we can aggregate asset data in a huge batch on the
 *      node's side and pull it to the client.
 */
contract AssetParametersViewer {
    IVaultParameters public immutable vaultParameters;

    IVaultManagerParameters public immutable vaultManagerParameters;
    IForceTransferAssetStore public immutable forceTransferAssetStore;

    struct AssetParametersStruct {
        // asset address
        address asset;

        // Percentage with 3 decimals
        uint stabilityFee;

        // Percentage with 0 decimals
        uint liquidationFee;

        // Percentage with 0 decimals
        uint initialCollateralRatio;

        // Percentage with 0 decimals
        uint liquidationRatio;

        // Percentage with 3 decimals
        uint liquidationDiscount;

        // Devaluation period in blocks
        uint devaluationPeriod;

        // USDP mint limit
        uint tokenDebtLimit;

        // Oracle types enabled for this asset
        uint[] oracles;

        // Percentage with 0 decimals
        uint minColPercent;

        // Percentage with 0 decimals
        uint maxColPercent;

        // Percentage with 2 decimals (basis points)
        uint borrowFee;

        bool forceTransferAssetToOwnerOnLiquidation;
        bool forceMoveWrappedAssetPositionOnLiquidation;
    }


    constructor(address _vaultManagerParameters, address _forceTransferAssetStore) {
        IVaultManagerParameters vmp = IVaultManagerParameters(_vaultManagerParameters);
        vaultManagerParameters = vmp;
        vaultParameters = IVaultParameters(vmp.vaultParameters());
        forceTransferAssetStore = IForceTransferAssetStore(_forceTransferAssetStore);
    }

    /**
     * @notice Get parameters of one asset
     * @param asset asset address
     * @param maxOracleTypesToSearch since complete list of oracle types is unknown, we'll check types up to this number
     */
    function getAssetParameters(address asset, uint maxOracleTypesToSearch)
        public
        view
        returns (AssetParametersStruct memory r)
    {
        r.asset = asset;
        r.stabilityFee = vaultParameters.stabilityFee(asset);
        r.liquidationFee = vaultParameters.liquidationFee(asset);

        r.initialCollateralRatio = vaultManagerParameters.initialCollateralRatio(asset);
        r.liquidationRatio = vaultManagerParameters.liquidationRatio(asset);
        r.liquidationDiscount = vaultManagerParameters.liquidationDiscount(asset);
        r.devaluationPeriod = vaultManagerParameters.devaluationPeriod(asset);

        r.tokenDebtLimit = vaultParameters.tokenDebtLimit(asset);

        r.minColPercent = vaultManagerParameters.minColPercent(asset);
        r.maxColPercent = vaultManagerParameters.maxColPercent(asset);

        r.borrowFee = 0;
        r.forceTransferAssetToOwnerOnLiquidation = forceTransferAssetStore.shouldForceTransfer(asset);
        r.forceMoveWrappedAssetPositionOnLiquidation = false;

        // Memory arrays can't be reallocated so we'll overprovision
        uint[] memory foundOracleTypes = new uint[](maxOracleTypesToSearch);
        uint actualOraclesCount = 0;

        for (uint _type = 0; _type < maxOracleTypesToSearch; ++_type) {
            if (vaultParameters.isOracleTypeEnabled(_type, asset)) {
                foundOracleTypes[actualOraclesCount++] = _type;
            }
        }

        r.oracles = new uint[](actualOraclesCount);
        for (uint i = 0; i < actualOraclesCount; ++i) {
            r.oracles[i] = foundOracleTypes[i];
        }
    }

    /**
     * @notice Get parameters of many assets
     * @param assets asset addresses
     * @param maxOracleTypesToSearch since complete list of oracle types is unknown, we'll check types up to this number
     */
    function getMultiAssetParameters(address[] calldata assets, uint maxOracleTypesToSearch)
        external
        view
        returns (AssetParametersStruct[] memory r)
    {
        uint length = assets.length;
        r = new AssetParametersStruct[](length);
        for (uint i = 0; i < length; ++i) {
            r[i] = getAssetParameters(assets[i], maxOracleTypesToSearch);
        }
    }
}
