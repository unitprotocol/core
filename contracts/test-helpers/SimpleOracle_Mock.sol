// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IOracleUsd.sol";

/**
 * @title SimpleOracle_Mock
 * @dev Mock implementation of an oracle used for testing purposes. This mock oracle provides a simplistic conversion of an asset to its USD representation by multiplying the input amount by a fixed number.
 */
contract SimpleOracle_Mock is IOracleUsd {

    /**
     * @notice Converts the asset amount to its equivalent USD value.
     * @dev This mock function simply multiplies the input amount by a fixed conversion rate (1234).
     * @param amount The amount of the asset to be converted to USD.
     * @return uint The equivalent USD value of the input asset amount.
     */
    function assetToUsd(address /* asset */, uint amount) public override pure returns (uint) {
        return amount * 1234;
    }
}