// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "../VaultParameters.sol";

contract OracleRegistry is Auth {

    // map token to oracle address
    mapping(address => address) public oracleByAsset;

    // map oracle ID to oracle address
    mapping(uint => address) public oracleByType;

    constructor(address vaultParameters) Auth(vaultParameters) {
        require(vaultParameters != address(0), "Unit Protocol: ZERO_ADDRESS");
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the oracle address
     * @param asset The address of the collateral
     * @param oracle The oracle address
     * @param oracleType The oracle type ID
     **/
    function setOracle(address asset, address oracle, uint oracleType) public onlyManager {
        require(asset != address(0) && oracleType != 0, "Unit Protocol: INVALID_ARGS");
        oracleByAsset[asset] = oracle;
        oracleByType[oracleType] = oracle;
    }

}
