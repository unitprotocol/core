// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../USDP.sol";
import "./IAssetTestsMint.sol";

/**
 * @title USDPMock
 * @dev Mock contract for USDP token used for testing purposes.
 * Inherits from USDP and implements the IAssetTestsMint interface.
 */
contract USDPMock is USDP, IAssetTestsMint {
    using SafeMath for uint;

    /**
     * @dev Constructor that initializes the USDPMock contract.
     * @param _parameters The address of the contract containing system parameters.
     */
    constructor(address _parameters) USDP(_parameters) {}

    /**
     * @dev Mints USDP tokens to a specified address for testing purposes.
     * @param to The address to which the tokens will be minted.
     * @param amount The amount of tokens to mint.
     * Requirements:
     * - `to` cannot be the zero address.
     */
    function tests_mint(address to, uint amount) public override {
        require(to != address(0), "Unit Protocol: ZERO_ADDRESS");

        balanceOf[to] = balanceOf[to].add(amount);
        totalSupply = totalSupply.add(amount);
    }
}