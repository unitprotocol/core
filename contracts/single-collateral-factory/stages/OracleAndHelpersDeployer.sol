// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./AbstractDeployer.sol";
import "../../oracles/ChainlinkedOracleMainAsset.sol";
import "../../helpers/AssetParametersViewer.sol";
import "../../helpers/CDPViewer.sol";

contract OracleAndHelpersDeployer is AbstractDeployer {

    function deployStage(IFactory.Deploy memory deploy_) public override onlyManager returns (address[] memory result_) {
        require(
            deploy_.vaultParameters != address(0)
            && deploy_.vaultManagerParameters != address(0)
            && deploy_.vaultManagerBorrowFeeParameters != address(0)
            && deploy_.assetsBooleanParameters != address(0)
            && deploy_.oracleRegistry != address(0),
            "FACTORY: BROKEN_LOGIC"
        );

        address[] memory tokens = new address[](1);
        tokens[0] = deploy_.deploySettings.collateral;
        address[] memory aggregators = new address[](1);
        aggregators[0] = deploy_.deploySettings.chainlinkAggregator;
        ChainlinkedOracleMainAsset oracle = new ChainlinkedOracleMainAsset(
            tokens, aggregators,
            new address[](0), new address[](0),
            address(1), deploy_.vaultParameters
        );

        AssetParametersViewer assetParametersViewer = new AssetParametersViewer(
            deploy_.vaultManagerParameters,
            deploy_.vaultManagerBorrowFeeParameters,
            deploy_.assetsBooleanParameters
        );

        CDPViewer cdpViewer = new CDPViewer(
            deploy_.vaultManagerParameters,
            deploy_.oracleRegistry,
            deploy_.vaultManagerBorrowFeeParameters
        );

        result_ = new address[](3);
        result_[0] = address(oracle);
        result_[1] = address(assetParametersViewer);
        result_[2] = address(cdpViewer);
    }
}
