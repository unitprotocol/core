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
 * @dev Oracle to quote wrapped tokens to underlying. This contract allows you to set and retrieve the underlying asset for a wrapped token, as well as to get the USD price of an asset.
 */
contract WrappedToUnderlyingOracle is IOracleUsd, Auth {

    IOracleRegistry public immutable oracleRegistry;

    mapping (address => address) public assetToUnderlying;

    /**
     * @dev Emitted when a new underlying asset is set for a wrapped token.
     * @param wrapped The address of the wrapped token.
     * @param underlying The address of the underlying token.
     */
    event NewUnderlying(address indexed wrapped, address indexed underlying);

    /**
     * @dev Constructs the WrappedToUnderlyingOracle contract.
     * @param _vaultParameters The address of the VaultParameters contract.
     * @param _oracleRegistry The address of the OracleRegistry contract.
     */
    constructor(address _vaultParameters, address _oracleRegistry) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    /**
     * @dev Sets the underlying asset for a wrapped token.
     * @param wrapped The address of the wrapped token.
     * @param underlying The address of the underlying token.
     */
    function setUnderlying(address wrapped, address underlying) external onlyManager {
        assetToUnderlying[wrapped] = underlying;
        emit NewUnderlying(wrapped, underlying);
    }

    /**
     * @dev Returns the USD price of an asset as a Q112-encoded value.
     * @param asset The address of the asset for which to get the USD price.
     * @param amount The amount of the asset.
     * @return The USD price of the given amount of the asset, Q112-encoded.
     */
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;

        (address oracle, address underlying) = _getOracleAndUnderlying(asset);

        return IOracleUsd(oracle).assetToUsd(underlying, amount);
    }

    /**
     * @dev Internal function to get the oracle and underlying asset for a given asset.
     * @param asset The address of the asset for which to get the oracle and underlying asset.
     * @return oracle The address of the oracle for the underlying asset.
     * @return underlying The address of the underlying asset.
     */
    function _getOracleAndUnderlying(address asset) internal view returns (address oracle, address underlying) {

        underlying = assetToUnderlying[asset];
        require(underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");

        oracle = oracleRegistry.oracleByAsset(underlying);
        require(oracle != address(0), "Unit Protocol: NO_ORACLE_FOUND");
    }
}