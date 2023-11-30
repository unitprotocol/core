// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title CurveProviderMock
 * @dev Mock contract for Curve provider interactions.
 */
contract CurveProviderMock {

    // Address of the Curve registry contract.
    address public immutable get_registry;

    /**
     * @dev Constructs the CurveProviderMock contract.
     * @param registry The address of the Curve registry contract.
     */
    constructor (address registry) {
        get_registry = registry;
    }
}

/**
 * @title CurveRegistryMock
 * @dev Mock contract for Curve registry interactions.
 */
contract CurveRegistryMock {

    // Mapping from LP token to the corresponding pool.
    mapping (address => address) public get_pool_from_lp_token;
    // Internal mapping to store the number of coins for each pool.
    mapping (address => uint[2]) _get_n_coins;

    /**
     * @dev Constructs the CurveRegistryMock contract and initializes a pool with LP token and number of coins.
     * @param lp The LP token address.
     * @param pool The pool address.
     * @param nCoins The number of coins in the pool.
     */
    constructor (address lp, address pool, uint nCoins) {
        setLP(lp, pool, nCoins);
    }

    /**
     * @dev Sets the LP token and pool information.
     * @param lp The LP token address.
     * @param pool The pool address.
     * @param nCoins The number of coins in the pool.
     */
    function setLP(address lp, address pool, uint nCoins) public {
        get_pool_from_lp_token[lp] = pool;
        uint[2] memory nCoinsArray = [nCoins, nCoins];
        _get_n_coins[pool] = nCoinsArray;
    }

    /**
     * @dev Retrieves the number of coins for a given pool.
     * @param pool The pool address.
     * @return An array with two elements, both representing the number of coins in the pool.
     */
    function get_n_coins(address pool) external view returns (uint[2] memory) {
        return _get_n_coins[pool];
    }
}

/**
 * @title CurvePool
 * @dev Mock contract for Curve pool interactions.
 */
contract CurvePool {

    // The virtual price of the pool.
    uint public get_virtual_price;
    // Mapping from index to coin addresses in the pool.
    mapping (uint => address) public coins;

    /**
     * @dev Sets the virtual price and coins of the pool.
     * @param virtualPrice The virtual price to set for the pool.
     * @param _coins The array of coin addresses to set for the pool.
     */
    function setPool(uint virtualPrice, address[] calldata _coins) public {
        get_virtual_price = virtualPrice;
        for (uint i = 0; i < _coins.length; i++) {
            coins[i] = _coins[i];
        }
    }
}