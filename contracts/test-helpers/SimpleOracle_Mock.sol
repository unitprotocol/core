// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IOracleUsd.sol";

/**
 * @title SimpleOracle_Mock
 * @dev Used in tests
 **/
contract SimpleOracle_Mock is IOracleUsd {

    function assetToUsd(address /* asset */, uint amount) public override pure returns (uint) {
        return amount * 1234;
    }
}
