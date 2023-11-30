// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IBoneToken Interface
 * @dev Interface for the BoneToken which extends the IERC20 standard with a minting function.
 */
interface IBoneToken is IERC20 {

    /**
     * @notice Mints tokens to the specified address.
     * @dev Allows for the creation of tokens to be added to the supply.
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external;
}