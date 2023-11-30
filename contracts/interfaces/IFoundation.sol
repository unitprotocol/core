// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.7.6;

/**
 * @title Interface for Foundation contract
 * @dev This interface declares a function for submitting liquidation fees.
 */
interface IFoundation {

    /**
     * @dev Submits a liquidation fee to the Foundation.
     * @param fee The amount of the liquidation fee to submit.
     */
    function submitLiquidationFee(uint fee) external;
}