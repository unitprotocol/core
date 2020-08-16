// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;

contract ChainlinkAggregatorMock {
    uint public latestAnswer = 250e8;
    uint public latestTimestamp = now;
}
