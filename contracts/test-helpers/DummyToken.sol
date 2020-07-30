// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.6.6;

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
    public
    {
    }
}
