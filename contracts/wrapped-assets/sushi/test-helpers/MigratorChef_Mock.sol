// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./MasterChef_Mock.sol";

contract MigratorChef_Mock is IMigratorChef {

    IERC20 public newToken;

    function migrate(IERC20 token) external override returns (IERC20) {
        newToken.transfer(msg.sender, token.balanceOf(msg.sender));
        return newToken;
    }

    function setNewToken(IERC20 token) public {
       newToken = token;
    }
}