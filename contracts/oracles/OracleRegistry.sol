// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma abicoder v2;

import "../VaultParameters.sol";

contract OracleRegistry is Auth {
    
    struct Oracle {
        uint oracleType;
        address oracleAddress;
    }

    uint public maxOracleType;

    address public immutable WETH;

    // map asset to oracle type ID
    mapping(address => uint) public oracleTypeByAsset;

    // map oracle type ID to oracle address
    mapping(uint => address) public oracleByType;

    // map oracle address to oracle type ID
    mapping(address => uint) public oracleTypeByOracle;

    event AssetOracle(address indexed asset, uint indexed oracleType);
    event OracleType(uint indexed oracleType, address indexed oracle);

    constructor(address vaultParameters, address _weth) Auth(vaultParameters) {
        require(vaultParameters != address(0) && _weth != address(0), "Unit Protocol: ZERO_ADDRESS");
        WETH = _weth;
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
        oracleTypeByOracle[oracle] = oracleType;

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

    function getOracles() external view returns (Oracle[] memory foundOracles) {

        foundOracles = new Oracle[](maxOracleType);

        for (uint _type = 0; _type < maxOracleType; ++_type) {
            foundOracles[_type] = Oracle(_type, oracleByType[_type]);
        }
    }

    function oracleByAsset(address asset) external view returns (address) {
        return oracleByType[oracleTypeByAsset[asset]];
    }

}
