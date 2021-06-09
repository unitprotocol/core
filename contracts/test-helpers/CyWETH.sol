// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./EmptyToken.sol";


contract CyWETH is EmptyToken {

  address public underlying;

  address public implementation;

  uint public exchangeRateStoredInternal;

    constructor(
        uint          _totalSupply,
        address       _underlying,
        address       _implementation,
        uint          _exchangeRateStoredInternal
    ) EmptyToken(
        "Yearn Wrapped Ether",
        "cyWETH",
        8,
        _totalSupply,
        msg.sender
    )
    {
      underlying = _underlying;
      implementation = _implementation;
      exchangeRateStoredInternal = _exchangeRateStoredInternal;
    }

    function exchangeRateStored() public view returns (uint) {
        return exchangeRateStoredInternal;
    }

}
