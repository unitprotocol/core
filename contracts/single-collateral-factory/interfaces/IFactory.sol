// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../../interfaces/IVersioned.sol";

interface IFactory is IVersioned {

    struct DeploySettings {
        string stableName;
        string stableSymbol;

        address commonFeeCollector;
        address issuanceFeeCollector;

        address collateral;
        address chainlinkAggregator;

        uint16 issuanceFeeBasisPoints;
        uint stabilityFeePercent3Decimals;
        uint liquidationFeePercent;

        uint initialCollateralRatioPercent;
        uint liquidationRatioPercent;
        uint liquidationDiscountPercent3Decimals;
        uint devaluationPeriodSeconds;
    }

    struct Deploy {
        uint8 stage;
        bool isFinished;

        DeploySettings deploySettings;

        address usdp;
        address vaultParameters;
        address vault;

        address collateralRegistry;
        address cdpRegistry;
        address oracleRegistry;

        address vaultManagerParameters;
        address vaultManagerBorrowFeeParameters;
        address assetsBooleanParameters;

        address cdpManager;
        address liquidationAuction;

        address chainlinkOracle;
        address assetParametersViewer;
        address cdpViewer;
    }

    event DeployInitialized(uint indexed deployId);
    event StageDeployed(uint indexed deployId, uint8 stage);
    event DeployFinished(uint indexed deployId);

    event VaultDeployed(uint indexed deployId, address indexed vaultAddress);
}
