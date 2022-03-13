// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EmptyToken is ERC20 {
    using SafeMath for uint;

    event Burn(address indexed burner, uint value);

    function burn(uint _value) public returns (bool) {
        require(_value <= balanceOf(msg.sender), "BURN_INSUFFICIENT_BALANCE");

        _burn(msg.sender, _value);
        return true;
    }

    function burnFrom(address _owner, uint _value) public returns (bool) {
        require(_owner != address(0), "ZERO_ADDRESS");
        require(_value <= balanceOf(_owner), "BURNFROM_INSUFFICIENT_BALANCE");
        require(_value <= allowance(_owner, msg.sender), "BURNFROM_INSUFFICIENT_ALLOWANCE");

        _burn(_owner, _value);
        return true;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8         _decimals,
        uint          _totalSupply,
        address       _firstHolder
    ) ERC20(_name, _symbol)
    {
        require(_firstHolder != address(0), "ZERO_ADDRESS");
        checkSymbolAndName(_symbol,_name);

        _setupDecimals(_decimals);

        _mint(_firstHolder, _totalSupply);
    }

    // Make sure symbol has 3-8 chars in [A-Za-z._] and name has up to 128 chars.
    function checkSymbolAndName(
        string memory _symbol,
        string memory _name
    )
    internal
    pure
    {
        bytes memory s = bytes(_symbol);
        require(s.length >= 3 && s.length <= 8, "INVALID_SIZE");
        for (uint i = 0; i < s.length; i++) {
            // make sure symbol contains only [A-Za-z._]
            require(
                s[i] == 0x2E || (
            s[i] == 0x5F) || (
            s[i] >= 0x41 && s[i] <= 0x5A) || (
            s[i] >= 0x61 && s[i] <= 0x7A), "INVALID_VALUE");
        }
        bytes memory n = bytes(_name);
        require(n.length >= s.length && n.length <= 128, "INVALID_SIZE");
        for (uint i = 0; i < n.length; i++) {
            require(n[i] >= 0x20 && n[i] <= 0x7E, "INVALID_VALUE");
        }
    }
}
