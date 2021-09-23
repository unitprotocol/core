// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IFoundation.sol";


contract FoundationMock is IFoundation {
  function submitLiquidationFee(uint fee) external override {}
}
