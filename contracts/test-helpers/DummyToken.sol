// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "./EmptyToken.sol";


contract DummyToken is EmptyToken {

    constructor(
        string memory _name,
        string memory _symbol,
        uint8         _decimals,
        uint          _totalSupply
    ) EmptyToken(
        _name,
        _symbol,
        _decimals,
        _totalSupply,
        msg.sender
    )
    public {}
}
