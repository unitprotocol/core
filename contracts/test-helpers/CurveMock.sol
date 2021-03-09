// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;


contract CurveProviderMock {

    address public immutable get_registry;

    constructor (address registry) {
        get_registry = registry;
    }
}


contract CurveRegistryMock {

    mapping (address => address) public get_pool_from_lp_token;
    mapping (address => uint) public get_virtual_price_from_lp_token;

    constructor (address lp, address pool, uint virtualPrice) {
        setLP(lp, pool, virtualPrice);
    }

    function setLP(address lp, address pool, uint virtualPrice) public {
        get_pool_from_lp_token[lp] = pool;
        get_virtual_price_from_lp_token[lp] = virtualPrice;
    }
}
