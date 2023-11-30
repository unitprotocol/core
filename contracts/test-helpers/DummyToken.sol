// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./EmptyToken.sol";

/**
 * @title DummyToken
 * @dev This contract extends the EmptyToken contract and allows the creation of a dummy token.
 */
contract DummyToken is EmptyToken {

    /**
     * @dev Constructor for DummyToken.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _decimals The number of decimals the token uses.
     * @param _totalSupply The total supply of the token.
     */
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
    {}
}