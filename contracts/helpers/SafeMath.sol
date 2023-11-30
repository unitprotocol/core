// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/* 
 * @title SafeMath
 * @dev Library for safe mathematical operations which prevents overflow and underflow.
 */
library SafeMath {

    /* 
     * @dev Multiplies two numbers, reverts on overflow.
     * @param a The first number as a uint256.
     * @param b The second number as a uint256.
     * @return c The product as a uint256.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /* 
     * @dev Divides one number by another, reverts on division by zero.
     * @param a The dividend as a uint256.
     * @param b The divisor as a uint256.
     * @return The quotient as a uint256.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: division by zero");
        return a / b;
    }

    /* 
     * @dev Subtracts one number from another, reverts if the result would be negative.
     * @param a The number to subtract from as a uint256.
     * @param b The number to subtract as a uint256.
     * @return The difference as a uint256.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /* 
     * @dev Adds two numbers, reverts on overflow.
     * @param a The first number to add as a uint256.
     * @param b The second number to add as a uint256.
     * @return c The sum as a uint256.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}