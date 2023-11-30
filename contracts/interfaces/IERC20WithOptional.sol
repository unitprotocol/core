// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Interface for ERC20 tokens with optional metadata functions
 * @dev Extends IERC20 to include optional metadata functions
 */
interface IERC20WithOptional is IERC20  {
    /**
     * @dev Returns the name of the token.
     * @return The token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     * @return The token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the number of decimals the token uses.
     * @return The number of decimals for getting user representation of a token amount.
     */
    function decimals() external view returns (uint8);
}