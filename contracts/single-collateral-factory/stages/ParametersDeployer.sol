// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./AbstractDeployer.sol";

import "../../vault-managers/parameters/VaultManagerParameters.sol";
import "../../vault-managers/parameters/AssetsBooleanParameters.sol";
import "../../vault-managers/parameters/VaultManagerBorrowFeeParameters.sol";

contract ParametersDeployer is AbstractDeployer {

    function deployStage(IFactory.Deploy memory deploy_) public override onlyManager returns (address[] memory result_) {
        require(
            deploy_.vaultParameters != address(0),
            "FACTORY: BROKEN_LOGIC"
        );

        VaultManagerParameters vaultManagerParameters = new VaultManagerParameters(deploy_.vaultParameters);

        VaultManagerBorrowFeeParameters vaultManagerBorrowFeeParameters = new VaultManagerBorrowFeeParameters(
            deploy_.vaultParameters, deploy_.deploySettings.issuanceFeeBasisPoints, deploy_.deploySettings.issuanceFeeCollector
        );

        address[] memory initialAssets = new address[](0);
        uint8[] memory initialParams = new uint8[](0);
        AssetsBooleanParameters assetsBooleanParameters = new AssetsBooleanParameters(
            deploy_.vaultParameters, initialAssets, initialParams
        );

        result_ = new address[](5);
        result_[0] = address(vaultManagerParameters);
        result_[1] = address(vaultManagerBorrowFeeParameters);
        result_[2] = address(assetsBooleanParameters);
    }
}
