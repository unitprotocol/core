// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;


contract CurveProviderMock {

    address public immutable get_registry;

    constructor (address registry) {
        get_registry = registry;
    }
}


contract CurveRegistryMock {

    mapping (address => address) public get_pool_from_lp_token;
    mapping (address => uint[2]) _get_n_coins;

    constructor (address lp, address pool, uint nCoins) {
        setLP(lp, pool, nCoins);
    }

    function setLP(address lp, address pool, uint nCoins) public {
        get_pool_from_lp_token[lp] = pool;
        uint[2] memory nCoinsArray = [nCoins, nCoins];
        _get_n_coins[pool] = nCoinsArray;
    }

    function get_n_coins(address pool) external view returns (uint[2] memory) {
        return _get_n_coins[pool];
    }
}


contract CurvePool {

    uint public get_virtual_price;
    mapping (uint => address) public coins;

    function setPool(uint virtualPrice, address[] calldata _coins) public {
        get_virtual_price = virtualPrice;
        for (uint i = 0; i < _coins.length; i ++) {
            coins[i] = _coins[i];
        }
    }
}
