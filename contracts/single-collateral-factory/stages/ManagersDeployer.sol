// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./AbstractDeployer.sol";

import "../../vault-managers/CDPManager01.sol";
import "../../auction/LiquidationAuction02.sol";

contract ManagersDeployer is AbstractDeployer {

    function deployStage(IFactory.Deploy memory deploy_) public override onlyManager returns (address[] memory result_) {
        require(
            deploy_.vaultManagerParameters != address(0)
            && deploy_.oracleRegistry != address(0)
            && deploy_.cdpRegistry != address(0)
            && deploy_.vaultManagerBorrowFeeParameters != address(0)
            && deploy_.assetsBooleanParameters != address(0),
            "FACTORY: BROKEN_LOGIC"
        );

        CDPManager01 cdpManager = new CDPManager01(
            deploy_.vaultManagerParameters,
            deploy_.oracleRegistry, deploy_.cdpRegistry,
            deploy_.vaultManagerBorrowFeeParameters
        );

        LiquidationAuction02 liquidationAuction = new LiquidationAuction02(
            deploy_.vaultManagerParameters,
            deploy_.cdpRegistry,
            deploy_.assetsBooleanParameters
        );

        result_ = new address[](2);
        result_[0] = address(cdpManager);
        result_[1] = address(liquidationAuction);
    }
}
