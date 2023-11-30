// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../interfaces/wrapped-assets/ISushiSwapLpToken.sol";

/**
 * @title SushiSwapLpToken_Mock
 * @dev Mock implementation of a SushiSwap liquidity pool token for testing purposes.
 * Inherits from ERC20 and implements ISushiSwapLpToken interface.
 */
contract SushiSwapLpToken_Mock is ERC20, ISushiSwapLpToken  {
    /// @notice Address of the first token in the liquidity pair.
    address public override token0;

    /// @notice Address of the second token in the liquidity pair.
    address public override token1;

    /**
     * @dev Sets the initial values for token0, token1, name, symbol, and decimals.
     * Mints 100 tokens to the address deploying the contract.
     * @param _token0 The address of the first token in the liquidity pair.
     * @param _token1 The address of the second token in the liquidity pair.
     * @param name_ The name of the liquidity pool token.
     * @param symbol_ The symbol of the liquidity pool token.
     * @param decimals_ The number of decimals the liquidity pool token uses.
     */
    constructor (address _token0, address _token1, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
    {
        token0 = _token0;
        token1 = _token1;

        _setupDecimals(decimals_);
        _mint(msg.sender, 100 ether);
    }
}