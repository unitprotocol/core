// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IFoundation.sol";

/**
 * @title FoundationMock
 * @dev Mock implementation of the IFoundation interface for testing purposes.
 */
contract FoundationMock is IFoundation {

    /**
     * @dev Submits the liquidation fee to the Foundation.
     * @param fee The fee amount to be submitted.
     */
    function submitLiquidationFee(uint fee) external override {}
}