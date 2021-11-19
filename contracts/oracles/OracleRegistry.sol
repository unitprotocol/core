// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma abicoder v2;

import "../VaultParameters.sol";
import "../interfaces/IOracleRegistry.sol";

contract OracleRegistry is IOracleRegistry, Auth {
    
    uint public override maxOracleType;

    address public immutable override WETH;

    // map asset to oracle type ID
    mapping(address => uint) public override oracleTypeByAsset;

    // map oracle type ID to oracle address
    mapping(uint => address) public override oracleByType;

    // map oracle address to oracle type ID
    mapping(address => uint) public override oracleTypeByOracle;

    // list of keydonix oracleType IDs
    uint[] public override keydonixOracleTypes;

    modifier validAddress(address asset) {
        require(asset != address(0), "Unit Protocol: ZERO_ADDRESS");
        _;
    }

    modifier validType(uint _type) {
        require(_type != 0, "Unit Protocol: INVALID_TYPE");
        _;
    }

    constructor(address vaultParameters, address _weth)
        Auth(vaultParameters)
        validAddress(vaultParameters)
        validAddress(_weth)
    {
        WETH = _weth;
    }

    function setKeydonixOracleTypes(uint[] calldata _keydonixOracleTypes) public override onlyManager {
        for (uint i = 0; i < _keydonixOracleTypes.length; i++) {
            require(_keydonixOracleTypes[i] != 0, "Unit Protocol: INVALID_TYPE");
            require(oracleByType[_keydonixOracleTypes[i]] != address(0), "Unit Protocol: INVALID_ORACLE");
        }

        keydonixOracleTypes = _keydonixOracleTypes;

        emit KeydonixOracleTypes();
    }

    function setOracle(uint oracleType, address oracle) public
        override
        onlyManager
        validType(oracleType)
        validAddress(oracle)
    {
        if (oracleType > maxOracleType) {
            maxOracleType = oracleType;
        }

        address oldOracle = oracleByType[oracleType];
        if (oldOracle != address(0)) {
            delete oracleTypeByOracle[oldOracle];
        }

        uint oldOracleType = oracleTypeByOracle[oracle];
        if (oldOracleType != 0) {
            delete oracleByType[oldOracleType];
        }

        oracleByType[oracleType] = oracle;
        oracleTypeByOracle[oracle] = oracleType;

        emit OracleType(oracleType, oracle);
    }

    function unsetOracle(uint oracleType) public override onlyManager validType(oracleType) validAddress(oracleByType[oracleType]) {
        address oracle = oracleByType[oracleType];
        delete oracleByType[oracleType];
        delete oracleTypeByOracle[oracle];

        emit OracleType(oracleType, address(0));
    }

    function setOracleTypeForAsset(address asset, uint oracleType) public
        override
        onlyManager
        validAddress(asset)
        validType(oracleType)
        validAddress(oracleByType[oracleType])
    {
        oracleTypeByAsset[asset] = oracleType;
        emit AssetOracle(asset, oracleType);
    }

    function setOracleTypeForAssets(address[] calldata assets, uint oracleType) public override {
        for (uint i = 0; i < assets.length; i++) {
            setOracleTypeForAsset(assets[i], oracleType);
        }
    }

    function unsetOracleForAsset(address asset) public
        override
        onlyManager
        validAddress(asset)
        validType(oracleTypeByAsset[asset])
    {
        delete oracleTypeByAsset[asset];
        emit AssetOracle(asset, 0);
    }

    function unsetOracleForAssets(address[] calldata assets) public override {
        for (uint i = 0; i < assets.length; i++) {
            unsetOracleForAsset(assets[i]);
        }
    }

    function getOracles() external override view returns (Oracle[] memory foundOracles) {

        Oracle[] memory allOracles = new Oracle[](maxOracleType);

        uint actualOraclesCount;

        for (uint _type = 1; _type <= maxOracleType; ++_type) {
            if (oracleByType[_type] != address(0)) {
                allOracles[actualOraclesCount++] = Oracle(_type, oracleByType[_type]);
            }
        }

        foundOracles = new Oracle[](actualOraclesCount);

        for (uint i = 0; i < actualOraclesCount; ++i) {
            foundOracles[i] = allOracles[i];
        }
    }

    function getKeydonixOracleTypes() external override view returns (uint[] memory) {
        return keydonixOracleTypes;
    }

    function oracleByAsset(address asset) external override view returns (address) {
        uint oracleType = oracleTypeByAsset[asset];
        if (oracleType == 0) {
            return address(0);
        }
        return oracleByType[oracleType];
    }

}
