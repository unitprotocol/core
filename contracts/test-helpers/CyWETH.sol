// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./EmptyToken.sol";

/* 
 * @title CyWETH
 * @notice This contract extends EmptyToken to represent a tokenized position in Yearn Wrapped Ether.
 */
contract CyWETH is EmptyToken {

    /* @notice The underlying asset of the Yearn Wrapped Ether. */
    address public underlying;

    /* @notice The address of the implementation contract. */
    address public implementation;

    /* @notice The stored exchange rate from the underlying to the Yearn Wrapped Ether. */
    uint public exchangeRateStoredInternal;

    /* 
     * @dev Initializes the contract with the initial state.
     * @param _totalSupply The initial total supply of the token.
     * @param _underlying The address of the underlying asset.
     * @param _implementation The address of the implementation contract.
     * @param _exchangeRateStoredInternal The initial exchange rate from the underlying to the Yearn Wrapped Ether.
     */
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

    /* 
     * @notice Returns the stored exchange rate from the underlying to the Yearn Wrapped Ether.
     * @return The current exchange rate as a uint.
     */
    function exchangeRateStored() public view returns (uint) {
        return exchangeRateStoredInternal;
    }

}