// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title ERC20Like
 * @dev Interface for the subset of the ERC20 standard.
 */
interface ERC20Like {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     * @param account The address of the account to check.
     * @return The amount of tokens owned.
     */
    function balanceOf(address account) external view returns (uint);

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * @return The number of decimals for this token.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     * @param recipient The address of the recipient.
     * @param amount The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
     * `amount` is then deducted from the caller's allowance.
     * @param sender The address of the sender.
     * @param recipient The address of the recipient.
     * @param amount The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the total token supply in existence.
     * @return The total token supply.
     */
    function totalSupply() external view returns (uint256);
}