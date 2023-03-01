// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./AbstractDeployer.sol";

import "../../CollateralRegistry.sol";
import "../../CDPRegistry.sol";
import "../../oracles/OracleRegistry.sol";


contract RegistriesDeployer is AbstractDeployer {

    function deployStage(IFactory.Deploy memory deploy_) public override onlyManager returns (address[] memory result_) {
        require(
            deploy_.vaultParameters != address(0)
            && deploy_.vault != address(0),
            "FACTORY: BROKEN_LOGIC"
        );

        CollateralRegistry collateralRegistry = new CollateralRegistry(deploy_.vaultParameters, new address[](0));
        CDPRegistry cdpRegistry = new CDPRegistry(deploy_.vault, address(collateralRegistry));
        OracleRegistry oracleRegistry = new OracleRegistry(deploy_.vaultParameters, address(1));

        result_ = new address[](3);
        result_[0] = address(collateralRegistry);
        result_[1] = address(cdpRegistry);
        result_[2] = address(oracleRegistry);
    }
}
