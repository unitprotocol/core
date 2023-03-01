// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./IFactory.sol";

interface IStageDeployer {
    function setManager(address manager_) external;
    function deployStage(IFactory.Deploy memory deploy_) external returns (address[] memory);
    function setUp(IFactory.Deploy memory deploy_) external;
}
