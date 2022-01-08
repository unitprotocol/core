// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IOracleRegistry.sol";
import "./KeydonixOracleAbstract.sol";
import "../Auth2.sol";

/**
 * @title WrappedToUnderlyingOracleKeydonix
 * @dev Oracle to quote wrapped tokens to underlying
 **/
contract WrappedToUnderlyingOracleKeydonix is KeydonixOracleAbstract, Auth2 {

    IOracleRegistry public immutable oracleRegistry;

    mapping (address => address) public assetToUnderlying;

    event NewUnderlying(address indexed wrapped, address indexed underlying);

    constructor(address _vaultParameters, address _oracleRegistry) Auth2(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    function setUnderlying(address wrapped, address underlying) external onlyManager {
        assetToUnderlying[wrapped] = underlying;
        emit NewUnderlying(wrapped, underlying);
    }

    // returns Q112-encoded value
    function assetToUsd(
        address asset,
        uint amount,
        ProofDataStruct memory proofData
    ) public override view returns (uint) {
        if (amount == 0) return 0;

        (address oracle, address underlying) = _getOracleAndUnderlying(asset);

        return KeydonixOracleAbstract(oracle).assetToUsd(underlying, amount, proofData);
    }

    /**
     * @dev for saving gas not checking underlying oracle for keydonix type since call to online oracle will fail anyway
     */
    function _getOracleAndUnderlying(address asset) internal view returns (address oracle, address underlying) {
        underlying = assetToUnderlying[asset];
        require(underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");

        oracle = oracleRegistry.oracleByAsset(underlying);
        require(oracle != address(0), "Unit Protocol: NO_ORACLE_FOUND");
    }

}
