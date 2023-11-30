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
 * @dev Oracle to quote wrapped tokens to their underlying assets.
 */
contract WrappedToUnderlyingOracleKeydonix is KeydonixOracleAbstract, Auth2 {

    /// @notice Oracle registry to fetch the current oracle for an underlying asset.
    IOracleRegistry public immutable oracleRegistry;

    /// @notice Mapping of wrapped tokens to their underlying tokens.
    mapping (address => address) public assetToUnderlying;

    /// @notice Event emitted when a new underlying asset is set for a wrapped token.
    event NewUnderlying(address indexed wrapped, address indexed underlying);

    /**
     * @dev Constructor for WrappedToUnderlyingOracleKeydonix.
     * @param _vaultParameters The address of the system's VaultParameters contract.
     * @param _oracleRegistry The address of the OracleRegistry contract.
     */
    constructor(address _vaultParameters, address _oracleRegistry) Auth2(_vaultParameters) {
        require(_oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    /**
     * @notice Sets the underlying asset for a wrapped token.
     * @dev Only callable by the manager role.
     * @param wrapped The address of the wrapped token.
     * @param underlying The address of the underlying token.
     */
    function setUnderlying(address wrapped, address underlying) external onlyManager {
        assetToUnderlying[wrapped] = underlying;
        emit NewUnderlying(wrapped, underlying);
    }

    /**
     * @notice Retrieves the USD value of the asset provided in the amount specified.
     * @dev Returns a Q112-encoded value, which is a value shifted left by 112 bits to retain fractional precision.
     * @param asset The address of the asset to be quoted.
     * @param amount The amount of the asset to be quoted.
     * @param proofData The proof data required for the oracle to function.
     * @return The USD value of the asset amount provided, encoded in Q112 format.
     */
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
     * @dev Internal function to get the oracle and underlying asset for a wrapped token.
      * @dev for saving gas not checking underlying oracle for keydonix type since call to online oracle will fail anyway
     * @param asset The address of the wrapped token.
     * @return oracle The oracle address for the underlying asset.
     * @return underlying The underlying asset address.
     */
    function _getOracleAndUnderlying(address asset) internal view returns (address oracle, address underlying) {
        underlying = assetToUnderlying[asset];
        require(underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");

        oracle = oracleRegistry.oracleByAsset(underlying);
        require(oracle != address(0), "Unit Protocol: NO_ORACLE_FOUND");
    }
}