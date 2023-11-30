// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma abicoder v2;

import "../VaultParameters.sol";

/**
 * @title OracleRegistry
 * @dev Contract that manages the registry of oracles for different asset types.
 */
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

    // list of keydonix oracleType IDs
    uint[] public keydonixOracleTypes;

    event AssetOracle(address indexed asset, uint indexed oracleType);
    event OracleType(uint indexed oracleType, address indexed oracle);
    event KeydonixOracleTypes();

    modifier validAddress(address asset) {
        require(asset != address(0), "Unit Protocol: ZERO_ADDRESS");
        _;
    }

    modifier validType(uint _type) {
        require(_type != 0, "Unit Protocol: INVALID_TYPE");
        _;
    }

    /**
     * @dev Constructor for OracleRegistry.
     * @param vaultParameters The address of the VaultParameters contract.
     * @param _weth The address of the wrapped ETH token.
     */
    constructor(address vaultParameters, address _weth)
        Auth(vaultParameters)
        validAddress(vaultParameters)
        validAddress(_weth)
    {
        WETH = _weth;
    }

    /**
     * @dev Sets the keydonix oracle types.
     * @param _keydonixOracleTypes An array of oracle type IDs.
     */
    function setKeydonixOracleTypes(uint[] calldata _keydonixOracleTypes) public onlyManager {
        for (uint i = 0; i < _keydonixOracleTypes.length; i++) {
            require(_keydonixOracleTypes[i] != 0, "Unit Protocol: INVALID_TYPE");
            require(oracleByType[_keydonixOracleTypes[i]] != address(0), "Unit Protocol: INVALID_ORACLE");
        }

        keydonixOracleTypes = _keydonixOracleTypes;

        emit KeydonixOracleTypes();
    }

    /**
     * @dev Sets or updates the oracle for a given oracle type.
     * @param oracleType The oracle type ID.
     * @param oracle The oracle address.
     */
    function setOracle(uint oracleType, address oracle) public
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

    /**
     * @dev Unsets the oracle for a given oracle type.
     * @param oracleType The oracle type ID to unset.
     */
    function unsetOracle(uint oracleType) public onlyManager validType(oracleType) validAddress(oracleByType[oracleType]) {
        address oracle = oracleByType[oracleType];
        delete oracleByType[oracleType];
        delete oracleTypeByOracle[oracle];

        emit OracleType(oracleType, address(0));
    }

    /**
     * @dev Sets the oracle type for a specific asset.
     * @param asset The asset address.
     * @param oracleType The oracle type ID.
     */
    function setOracleTypeForAsset(address asset, uint oracleType) public
        onlyManager
        validAddress(asset)
        validType(oracleType)
        validAddress(oracleByType[oracleType])
    {
        oracleTypeByAsset[asset] = oracleType;
        emit AssetOracle(asset, oracleType);
    }

    /**
     * @dev Sets the oracle type for multiple assets.
     * @param assets An array of asset addresses.
     * @param oracleType The oracle type ID.
     */
    function setOracleTypeForAssets(address[] calldata assets, uint oracleType) public {
        for (uint i = 0; i < assets.length; i++) {
            setOracleTypeForAsset(assets[i], oracleType);
        }
    }

    /**
     * @dev Unsets the oracle type for a specific asset.
     * @param asset The asset address to unset.
     */
    function unsetOracleForAsset(address asset) public
        onlyManager
        validAddress(asset)
        validType(oracleTypeByAsset[asset])
    {
        delete oracleTypeByAsset[asset];
        emit AssetOracle(asset, 0);
    }

    /**
     * @dev Unsets the oracle type for multiple assets.
     * @param assets An array of asset addresses.
     */
    function unsetOracleForAssets(address[] calldata assets) public {
        for (uint i = 0; i < assets.length; i++) {
            unsetOracleForAsset(assets[i]);
        }
    }

    /**
     * @dev Retrieves all active oracles with their types.
     * @return foundOracles An array of Oracle structs containing oracle types and addresses.
     */
    function getOracles() external view returns (Oracle[] memory foundOracles) {

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

    /**
     * @dev Retrieves the keydonix oracle types.
     * @return An array of keydonix oracle type IDs.
     */
    function getKeydonixOracleTypes() external view returns (uint[] memory) {
        return keydonixOracleTypes;
    }

    /**
     * @dev Retrieves the oracle address for a specific asset.
     * @param asset The asset address.
     * @return The address of the oracle associated with the asset.
     */
    function oracleByAsset(address asset) external view returns (address) {
        uint oracleType = oracleTypeByAsset[asset];
        if (oracleType == 0) {
            return address(0);
        }
        return oracleByType[oracleType];
    }

}