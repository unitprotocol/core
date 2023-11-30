// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./TopDog_Mock.sol";

/**
 * @title MigratorShib_Mock
 * @dev Mock contract for token migration.
 * This contract is only for testing purposes and simulates the migration process.
 */
contract MigratorShib_Mock is IMigratorShib {

    /// @notice The token that users will receive after the migration.
    IERC20 public newToken;

    /**
     * @dev Migrates the user's balance of the given token to the new token.
     * @param token The token to migrate from.
     * @return IERC20 The new token instance.
     */
    function migrate(IERC20 token) external override returns (IERC20) {
        newToken.transfer(msg.sender, token.balanceOf(msg.sender));
        return newToken;
    }

    /**
     * @dev Sets the new token to which the old tokens will be migrated.
     * @param token The new token contract address.
     */
    function setNewToken(IERC20 token) public {
       newToken = token;
    }
}