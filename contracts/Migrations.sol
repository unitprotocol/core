// SPDX-License-Identifier: bsl-1.1

pragma solidity 0.7.6;

/* 
 * @title Migrations
 * @dev This contract is used to manage migrations of the smart contract code.
 * It keeps track of the last completed migration script.
 */
contract Migrations {
  /* @dev Address of the contract owner. */
  address public owner;

  /* @dev Stores the last completed migration script number. */
  uint public last_completed_migration;

  /* 
   * @dev Sets the original owner of the contract to the sender account on contract creation.
   */
  constructor() {
    owner = msg.sender;
  }

  /* 
   * @dev Modifier to restrict the execution of functions to only the owner of the contract.
   * Reverts if the sender is not the owner.
   */
  modifier restricted() {
    if (msg.sender == owner) _;
    _;
  }

  /* 
   * @notice Sets the last completed migration script number.
   * @param completed The number of the last completed migration.
   * @dev Can only be called by the current owner of the contract.
   */
  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }
}