// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./IStageDeployer.sol";
import "./IWithNonce.sol";

interface IStageDeployerWithNonce is IStageDeployer, IWithNonce {
}