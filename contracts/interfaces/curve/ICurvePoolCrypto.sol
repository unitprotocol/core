// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

import "../ICurvePool.sol";

/**
 * @title ICurvePoolCrypto
 * @dev Interface for interacting with the Curve Crypto Pool contract.
 */
interface ICurvePoolCrypto is ICurvePool {

    /**
     * @notice Exchange one coin for another.
     * @param i The index value for the coin to send.
     * @param j The index value for the coin to receive.
     * @param dx The amount of i being exchanged.
     * @param min_dy The minimum amount of j to receive.
     */
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;

    /**
     * @notice Calculate the amount of coin j one would receive for amount dx of coin i.
     * @param i The index value for the coin to send.
     * @param j The index value for the coin to receive.
     * @param dx The amount of i to be exchanged.
     * @return The amount of coin j that would be received.
     */
    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);
}