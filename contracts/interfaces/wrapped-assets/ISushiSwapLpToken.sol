// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ISushiSwapLpToken
 * @dev Interface for SushiSwap's LP Token, extending IERC20 with token0 and token1 functions.
 */
interface ISushiSwapLpToken is IERC20 /* IERC20WithOptional */ {
    
    /**
     * @notice Get the address of the first token forming the liquidity pair.
     * @return address The address of the first token.
     */
    function token0() external view returns (address);
    
    /**
     * @notice Get the address of the second token forming the liquidity pair.
     * @return address The address of the second token.
     */
    function token1() external view returns (address);
}