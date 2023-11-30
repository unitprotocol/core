// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/* @title Math Library
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {

    /* @notice Calculate the maximum of two numbers
     * @param a The first number to compare
     * @param b The second number to compare
     * @return The larger of two input numbers
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /* @notice Calculate the minimum of two numbers
     * @param a The first number to compare
     * @param b The second number to compare
     * @return The smaller of two input numbers
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /* @notice Calculate the average of two numbers, rounding towards zero
     * @param a The first number
     * @param b The second number
     * @return The average of the two input numbers
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }

    /* @notice Calculate the square root of a number using the Babylonian method
     * @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
     * @param x The number to calculate the square root of
     * @return y The square root of the input number
     */
    function sqrt(uint x) internal pure returns (uint y) {
        if (x > 3) {
            uint z = x / 2 + 1;
            y = x;
            while (z < y) {
                y = z;
                z = (x / z + z) / 2;
            }
        } else if (x != 0) {
            y = 1;
        }
        // Note: if x is 0, y will be 0 (default value of uint)
    }
}