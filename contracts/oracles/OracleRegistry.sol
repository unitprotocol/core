// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../VaultParameters.sol";

contract OracleRegistry is Auth {

    uint public maxOracleType;

    // map token to oracle address
    mapping(address => uint) public oracleTypeByAsset;

    // map oracle ID to oracle address
    mapping(uint => address) public oracleByType;

    // map oracle address to oracle ID
    mapping(address => uint) public typeByOracle;

    event AssetOracle(address indexed asset, uint indexed oracleType);
    event OracleType(uint indexed oracleType, address indexed oracle);

    constructor(address vaultParameters) Auth(vaultParameters) {
        require(vaultParameters != address(0), "Unit Protocol: ZERO_ADDRESS");
    }

    function setOracleTypeToAsset(address asset, uint oracleType) public onlyManager {
        require(asset != address(0) && oracleType != 0, "Unit Protocol: INVALID_ARGS");
        oracleTypeByAsset[asset] = oracleType;
        emit AssetOracle(asset, oracleType);
    }

    function setOracle(uint oracleType, address oracle) public onlyManager {
        require(oracleType != 0, "Unit Protocol: INVALID_ARGS");

        if (oracleType > maxOracleType) {
            maxOracleType = oracleType;
        }

        oracleByType[oracleType] = oracle;
        typeByOracle[oracle] = oracleType;
        
        emit OracleType(oracleType, oracle);
    }

    function setOracleTypeToAssets(address[] calldata assets, uint oracleType) public onlyManager {
        require(oracleType != 0, "Unit Protocol: INVALID_ARGS");

        for (uint i = 0; i < assets.length; i++) {
            require(assets[i] != address(0), "Unit Protocol: ZERO_ADDRESS");
            oracleTypeByAsset[assets[i]] = oracleType;
            emit AssetOracle(assets[i], oracleType);
        }
    }

    function getOracles() external view returns (address[] memory oracles) {

        // Memory arrays can't be reallocated so we'll overprovision
        address[] memory foundOracles = new address[](maxOracleType - 1);
        uint actualOraclesCount = 0;

        for (uint _type = 1; _type <= maxOracleType; ++_type) {
            if (oracleByType[_type] != address(0)) {
                foundOracles[actualOraclesCount++] = oracleByType[_type];
            }
        }

        oracles = new address[](actualOraclesCount);
        for (uint i = 0; i < actualOraclesCount; ++i) {
            oracles[i] = foundOracles[i];
        }
    }

    function oracleByAsset(address asset) external view returns (address) {
        return oracleByType[oracleTypeByAsset[asset]];
    }

}
