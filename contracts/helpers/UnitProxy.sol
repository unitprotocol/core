// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";


contract UnitProxy is TransparentUpgradeableProxy {
  constructor(address _logic, address admin_, bytes memory _data)
  public
  payable
  TransparentUpgradeableProxy(_logic, admin_, _data) {}
}
