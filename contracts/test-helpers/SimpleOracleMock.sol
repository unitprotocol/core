// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IOracleUsd.sol";

/**
 * @title SimpleOracleMock
 * @dev Used in tests
 **/
contract SimpleOracleMock is IOracleUsd {

    uint public rate = 500 * 2**112;

    function setRate(uint _rate) public {
        rate = _rate;
    }

    function assetToUsd(address /* asset */, uint amount) public override view returns (uint) {
        return amount * rate;
    }
}
