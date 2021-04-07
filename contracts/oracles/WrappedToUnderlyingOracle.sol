// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../helpers/ERC20Like.sol";
import "../VaultParameters.sol";
import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleEth.sol";
import "../interfaces/IOracleRegistry.sol";

/**
 * @title WrappedToUnderlyingOracle
 * @dev Oracle to quote wrapped tokens to underlying
 **/
contract WrappedToUnderlyingOracle is IOracleUsd, Auth {

    IOracleRegistry public immutable oracleRegistry;

    mapping (address => address) public assetToUnderlying;

    event NewUnderlying(address indexed wrapped, address indexed underlying);

    constructor(address _vaultParameters, address _oracleRegistry) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    function setUnderlying(address wrapped, address underlying) external onlyManager {
        assetToUnderlying[wrapped] = underlying;
        emit NewUnderlying(wrapped, underlying);
    }

    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;

        (address oracle, address underlying) = _getOracleAndUnderlying(asset);

        return IOracleUsd(oracle).assetToUsd(underlying, amount);
    }

    function _getOracleAndUnderlying(address asset) internal view returns (address oracle, address underlying) {

        underlying = assetToUnderlying[asset];
        require(underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");

        oracle = oracleRegistry.oracleByAsset(underlying);
        require(oracle != address(0), "Unit Protocol: NO_ORACLE_FOUND");
    }

}
