// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../interfaces/IStageDeployer.sol";

abstract contract AbstractDeployer is IStageDeployer {

    address manager;

    modifier onlyManager {
        require(msg.sender == manager, "FACTORY: UNAUTHORIZED");
        _;
    }

    function setManager(address manager_) external override {
        require(manager == address(0), "FACTORY: ALREADY_INITIALIZED");
        manager = manager_;
    }

    function setUp(IFactory.Deploy memory deploy_) public virtual override {}
}
